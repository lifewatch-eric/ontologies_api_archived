
require 'ncbo_resource_index_client'

class ResourceIndexController < ApplicationController

  # Note: methods from resource_index_helper.rb :
  #  -  get_options(params)
  #  -  get_ontology_virtual_id(ontology_acronym)

  namespace "/resource_index" do


    # http://rest.bioontology.org/resource_index/ontologies
    # Return all ontologies
    get "/ontologies" do
      options = get_options(params)
      result = NCBO::ResourceIndex.ontologies(options)
      check404(result, "No ontologies found.")
      results_array = massage_ontologies(result, options)
      page = page_object(results_array) # page_object(array, total_result_count = 0)
      reply page
    end

    get '/search' do
      options = get_options(params)
      classes = get_classes(params)
      error 404, "You must provide valid `classes` to retrieve resources" if classes.empty?
      options[:elementDetails] = true
      result = NCBO::ResourceIndex.find_by_concept(classes, options)
      check404(result, "No concepts found.")
      #
      # TODO: Fix the get_annotated_class method (REDIS db failures), called by massage_search
      #
      results_array = massage_search(result, options)
      page = page_object(results_array)
      reply page
    end

    get '/ranked_elements' do
      options = get_options(params)
      classes = get_classes(params)
      error 404, "You must provide valid `classes` to retrieve resources" if classes.empty?
      result = NCBO::ResourceIndex.ranked_elements(classes, options)
      check404(result, "No elements found.")
      result.resources.each do |r|
        r[:elements] = massage_elements(r[:elements])
      end
      # TODO: Massage additional components (result.concepts)?
      page = page_object(result.resources)
      reply page
    end

    # Return all resources
    get "/resources" do
      options = get_options(params)
      result = NCBO::ResourceIndex.resources(options)
      check404(result, "No resources found.")
      #reply massage_resources(result)
      page = page_object(massage_resources(result))
      reply page
    end

    # Return specific resources
    get "/resources/:resources" do
      options = get_options(params)
      #result = NCBO::ResourceIndex.resources(options)
      result = NCBO::ResourceIndex.resources_hash(options)
      check404(result, "No resources found.")
      resources_filtered = []
      options[:resourceids].each do |r|
        rid = r.downcase.to_sym
        resources_filtered.push result[rid]
      end
      #reply massage_resources(result)
      page = page_object(massage_resources(resources_filtered))
      reply page
    end

    # Return a specific element from a specific resource
    get "/resources/:resources/elements/:elements" do
      options = get_options(params)
      result = NCBO::ResourceIndex.element(params["elements"], params["resources"], options)
      check404(result, "No element found.")
      # Massage the element data into the required format.
      element = { "id" => result.id }
      fields = {}
      result.text.each do |name, description|
        # TODO: Parse the text field to translate the term IDs into a list of URIs?
        #"text"=> "1351/D020224> 1351/D019295> 1351/D008969> 1351/D001483> 1351/D017398> 1351/D000465> 1351/D005796> 1351/D008433> 1351/D009690> 1351/D005091",
        #
        # Parse the associated ontologies to return a list of ontology URIs
        ontIDs = [result.ontoIds[name]].compact  # Wrap Fixnum or Array into Array
        ontIDs.delete_if {|x| x == 0 }
        ontIDs.each_with_index do |id, i|  # Try to convert to ontology URIs
          uri = ontology_uri_from_virtual_id(id)
          if uri.nil?
            ontIDs[i] = id.to_s # conform to expected data type for JSON validation
          else
            ontIDs[i] = uri
          end
        end
        weight = 0.0
        result.weights.each {|hsh| weight = hsh[:weight] if hsh[:name] == name}
        fields[name] = {
            "text" => description,
            "associatedOntologies" => ontIDs,
            "weight" => weight
        }
      end
      element["fields"] = fields
      reply element
    end


    def check404(response, message)
      error 404, message if response.nil?
      if response.is_a? Array
        error 404, message if response.empty?
      end
      if response.is_a? Hash
        error 404, message if response.empty?
      end
    end

    ##
    # Data massage methods.
    #


    def massage_ontologies(old_response, options)
      ontologies = []
      old_response.each do |ont|
        new = {
            :ontologyName => ont[:ontologyName],
            :ontologyURI => ontology_uri_from_virtual_id(ont[:virtualOntologyId])
        }
        if new[:ontologyURI].nil?
          # TODO: log error message
          # The RI contains an ontology that is not in the new API service, or the
          # REDIS store doesn't contain the lookup data?
          #puts "Failed to find RI ontology in REDIS lookup: #{ont[:virtualOntologyId]} - #{ont[:ontologyName]}"
        else
          ontologies.push(new)
        end
      end
      return ontologies
    end

    def massage_search(old_response, options)
      resources = {}
      old_response.each do |resource|
        elements = {}
        annotations = []
        resource.annotations.each do |a|
          annotated_class = get_annotated_class(a)
          # NOTE: Skipping nil class_uri values, could mess with paging details
          # The nil values are marginal cases for OBO terms
          next if annotated_class.nil?
          # NOTE: options[:scored] is not related to element weights.
          element = massage_element(a.element, options[:elementDetails])
          el_id = element["id"]
          elements[el_id] = element["fields"] unless elements.include?(el_id)
          annotations.push massage_search_annotation(a, annotated_class)
        end
        # TODO: add search option to exclude 0-element resources?
        resources[resource.resource] = {
            "id" => resource.resource,
            "annotations" => annotations,
            "annotatedElements" => elements
        }
      end
      return resources.values
    end

    # @param resource_annotation [{:localConceptId => 'version_id/term_id'}]
    # @return nil or annotated_class = { :id => 'term_uri', :ontology => 'ontology_uri'}
    def get_annotated_class(a)
      version_id, short_id = a.concept[:localConceptId].split('/')
      class_uri = uri_from_short_id(version_id, short_id)
      return nil if class_uri.nil?
      # undo the comment for testing purposes, only when class_uri.nil?
      #class_uri = a.concept[:localConceptId] if class_uri.nil?
      ontology_acronym = acronym_from_version_id(version_id)
      return nil if ontology_acronym.nil?
      ontology_uri = ontology_uri_from_acronym(ontology_acronym)
      return nil if ontology_uri.nil?

      ontology = LinkedData::Models::Ontology.read_only(id: RDF::IRI.new(ontology_uri), acronym: ontology_uri.split("/").last)
      submission = LinkedData::Models::OntologySubmission.read_only(id: RDF::IRI.new(ontology_uri+"/submissions/latest"), ontology: ontology)
      annotated_class = LinkedData::Models::Class.read_only(id: RDF::IRI.new(class_uri), submission: submission)

      # annotated_class = LinkedData::Models::Class.read_only(RDF::IRI.new(class_uri), {})
      # annotated_class.submissionAcronym = ontology_uri
      return annotated_class
    end

    def massage_search_annotation(a, annotated_class)
      # annotations is a hash of annotation hashes,
      # this method will modify it directly (by reference).
      annotationTypeMap = {
          "mgrepContext" => "direct",
          "mappingContext" => "mapping",
          "isaContext" => "hierarchy"
      }
      annotation = {
          :annotatedClass => annotated_class,
          :annotationType => annotationTypeMap[ a.context[:contextType] ],
          :elementField => a.context[:contextName],
          :elementId => a.element[:localElementId],
          :from => a.context[:from],
          :to => a.context[:to],
          #:score => a.score
      }
      return annotation
    end

    def massage_elements(element_array)
      # TODO: change this to use map! instead of each loop?
      elements = []
      element_array.each { |e| elements.push massage_element(e) }
      return elements
    end

    def massage_element(e, with_fields=true)
      element = { "id" => e[:localElementId] }
      if with_fields
        fields = {}
        e[:text].each do |name, description|
          # TODO: Parse the text field to translate the term IDs into a list of URIs?
          #"text"=> "1351/D020224> 1351/D019295> 1351/D008969> 1351/D001483> 1351/D017398> 1351/D000465> 1351/D005796> 1351/D008433> 1351/D009690> 1351/D005091",
          #
          # Parse the associated ontologies to return a list of ontology URIs
          ontIDs = [e[:ontoIds][name]].compact  # Wrap Fixnum or Array into Array
          ontIDs.delete_if {|x| x == 0 }
          ontIDs.each_with_index do |id, i|     # Try to convert to ontology URIs
            uri = ontology_uri_from_virtual_id(id)
            if uri.nil?
              ontIDs[i] = id.to_s # conform to expected data type for JSON validation
            else
              ontIDs[i] = uri
            end
          end
          weight = 0.0
          e[:weights].each {|hsh| weight = hsh[:weight] if hsh[:name] == name}
          fields[name] = {
            "text" => description,
            "associatedOntologies" => ontIDs,
            "weight" => weight
          }
        end
        element["fields"] = fields
      end
      return element
    end

    def massage_resources(resource_array)
      # Remove resource content
      resource_array.each do |r|
        r.delete :workflowCompletedDate
        r.delete :contexts
      end
      return resource_array.sort {|a,b| a[:resourceId] <=> b[:resourceId]}
    end

  end # namespace "/resource_index"

end # class ResourceIndexController
