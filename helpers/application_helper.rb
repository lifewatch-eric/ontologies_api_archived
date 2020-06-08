require 'sinatra/base'
require 'date'
require_relative '../utils/utils'

module Sinatra
  module Helpers
    module ApplicationHelper

      ##
      # Escape text for use in html
      def h(text)
        Rack::Utils.escape_html(text)
      end

      ##
      # Populate +obj+ using values from +params+
      # Will also try to find related objects using a Goo lookup.
      # TODO: Currerntly, this allows for mass-assignment of everything, which will permit
      # users to overwrite any attribute, including things like passwords.
      def populate_from_params(obj, params)
        begin #ecoportal: catch exception
          # LOGGER.debug(" ONTOLOGIES_API - application_helper->populate_from_params: \n\n    > obj:#{obj.nil? ? "nil" : obj.inspect}\n\n    > params:#{params.nil? ? "nil" : params.inspect}")
          return if obj.nil?

          # Make sure everything is loaded
          if obj.is_a?(LinkedData::Models::Base)
            #LOGGER.debug("\n\n   > obj.is_a?(LinkedData::Models::Base)")
            obj.bring_remaining unless !obj.exist?
          end
          # LOGGER.debug(" \n\n @@@ ONTOLOGIES_API - application_helper->populate_from_params - EACH 1 - params = #{params.inspect}")
          params.each do |attribute, value|
            # LOGGER.debug("\n\n>>>>>>>>>>>>>> attribute: #{attribute}, value: #{value} <<<<<<<<<<<<<<")
            next if value.nil?

            # Deal with empty strings
            
            empty_string = value.is_a?(String) && value.empty?
            old_string_value_exists = obj.respond_to?(attribute) && obj.send(attribute).is_a?(String)
            #LOGGER.debug("\n      - empty_string: #{empty_string}, \n      - old_string_value_exists: #{old_string_value_exists}")
            if old_string_value_exists && empty_string
              value = nil
            elsif empty_string
              next
            end

            attribute = attribute.to_sym
            attr_cls = obj.class.range(attribute)
            attribute_settings = obj.class.attribute_settings(attribute)
            not_hash_or_array = !value.is_a?(Hash) && !value.is_a?(Array)
            not_array_of_hashes = value.is_a?(Array) && !value.first.is_a?(Hash)

            #LOGGER.debug("\n      - attr_cls: #{attr_cls} \n      - attribute_settings: #{attribute_settings.inspect} \n      - not_hash_or_array: #{not_hash_or_array} \n      - not_array_of_hashes: #{not_array_of_hashes.inspect}  \n      - value.is_a?(Array): #{value.is_a?(Array)}")
            
            if attr_cls == LinkedData::Models::Class
              #LOGGER.debug("\n      - CASE A:")
              # Try to find dependent Goo objects, but only if the naming is not done via Proc
              # If naming is done via Proc, then try to lookup the Goo object using a hash of attributes
              is_arr = value.is_a?(Array)
              value = is_arr ? value : [value]
              new_value = []
              # LOGGER.debug(" \n\n @@@ ONTOLOGIES_API - application_helper->populate_from_params - EACH 2 - value = #{value.inspect}")
              value.each do |cls|
                sub = LinkedData::Models::Ontology.find(uri_as_needed(cls["ontology"])).first.latest_submission
                new_value << LinkedData::Models::Class.find(cls["class"]).in(sub).first
              end
              value = is_arr ? new_value : new_value[0]
            elsif attr_cls && not_hash_or_array || (attr_cls && not_array_of_hashes)
              # Replace the initial value with the object, handling Arrays as appropriate
              if value.is_a?(Array)
                # LOGGER.debug("\n      - CASE B1:")
                value = value.map {|e| attr_cls.find(uri_as_needed(e)).include(attr_cls.attributes).first}
              else
                # LOGGER.debug("\n      - CASE B2:")
                value = attr_cls.find(uri_as_needed(value)).include(attr_cls.attributes).first
              end
            elsif attr_cls
              # Check to see if the resource exists in the triplestore
              if value.is_a?(Array)
                # LOGGER.debug("\n      - CASE C1:")
                retrieved_values = []
                # LOGGER.debug(" \n\n @@@ ONTOLOGIES_API - application_helper->populate_from_params - EACH 3 - value = #{value.inspect}")
                value.each do |elem|
                  begin
                    # LOGGER.debug("\n\n     ------------------------------------------------------------\n")
                    symbolized_elem = OntologiesApi::Utils.recursive_symbolize_keys(elem, true, true)
                    #LOGGER.debug("\n      - elem:#{elem.inspect} \n\n      - symbolized_elem: #{symbolized_elem}")
                    retrieved_value = attr_cls.where(symbolized_elem).include(attr_cls.goo_attrs_to_load(includes_param, -2)).first
                    #LOGGER.debug("\n\n      - retrieved_value:#{retrieved_value.nil? ? "nil" : retrieved_value.inspect}")
                    # begin
                    #   #LOGGER.debug("\n\n ONTOLOGIES_API - application_helper->populate_from_params (CALL to_hash) #{retrieved_value.to_hash()}")
                    # rescue => e
                    #   #LOGGER.debug("\n\n ECCEZIONE - ONTOLOGIES_API - application_helper->populate_from_params (CALL to_hash) #{e.message}")
                    # end

                    retrieved_value_h = retrieved_value ? (retrieved_value.to_hash rescue nil) : nil
                    #LOGGER.debug("\n\n      - HASH of retrieved_value:#{retrieved_value_h.nil? ? "nil" : retrieved_value_h.inspect}")
                    if(retrieved_value_h)
                      #I found a similar object, but I have to verify if it is exactly the same (for example it has the same number of array's elements of the new object)
                      #To compare these objects I need to transform them in comparable hash format, for example HASH with the same attributes, the same  with the same order of array's element.
                      retrieved_value_h_symb = OntologiesApi::Utils.recursive_symbolize_keys(retrieved_value_h, true, true, [:id, :type, :links, :context, :created])
                      retrieved_value_h_ord = OntologiesApi::Utils.order_inner_array_elements(retrieved_value_h_symb, true, true, [:id, :type, :links, :context, :created])
                      
                      ordered_elem = OntologiesApi::Utils.order_inner_array_elements(symbolized_elem, true, true, [:id, :type, :links, :context, :created])
                      are_equivalent = ordered_elem.eql?(retrieved_value_h_ord) rescue ordered_elem == retrieved_value_h_ord
                      #LOGGER.debug("\n\n\n\n\n ============>> ordered_elem = #{ordered_elem} \n\n\n ============>> retrieved_value_h_ord = #{retrieved_value_h_ord}")
                      retrieved_value = are_equivalent ? retrieved_value : nil
                    end

                    if retrieved_value 
                      # LOGGER.debug("\n      - C1-1 retrieved_values << retrieved_value")
                      retrieved_values << retrieved_value
                    else
                      # LOGGER.debug("\n      - C1-2 recursive call -> pupolate_from_params -BEGIN ")
                      temp_retrieved_value = populate_from_params(attr_cls.new, symbolized_elem).save
                      retrieved_values << temp_retrieved_value
                      #LOGGER.debug("\n      - C1-2 recursive call -> pupolate_from_params -END: value saved and added=#{temp_retrieved_value}")
                      #retrieved_values << populate_from_params(attr_cls.new, e.symbolize_keys).save                   
                    end
                  rescue => e
                    LOGGER.debug("\n\n ###### ONTOLOGIES_API - application_helper->populate_from_params: ECCEZIONE: #{e.message}\n#{e.backtrace.join("\n")}")
                    raise e
                  end
                end
              else
                # LOGGER.debug("\n      - CASE C2:")
                retrieved_values = attr_cls.where(value.symbolize_keys).to_a
                unless retrieved_values
                  temp_retrieved_value = populate_from_params(attr_cls.new, e.symbolize_keys).save
                  retrieved_values = temp_retrieved_value
                  #retrieved_values = populate_from_params(attr_cls.new, e.symbolize_keys).save
                end
              end
              value = retrieved_values
            elsif attribute_settings && attribute_settings[:enforce] && attribute_settings[:enforce].include?(:date_time)
              # LOGGER.debug("\n      - CASE D: :date_time")
              # TODO: Remove this awful hack when obj.class.model_settings[:range][attribute] contains DateTime class
              value = DateTime.parse(value)
            elsif attribute_settings && attribute_settings[:enforce] && attribute_settings[:enforce].include?(:uri)
              # LOGGER.debug("\n      - CASE E: :uri")
              # TODO: Remove this awful hack when obj.class.model_settings[:range][attribute] contains RDF::IRI class
              value = RDF::IRI.new(value)
            end

            # Don't populate naming attributes if they exist
            if obj.class.model_settings[:name_with] != attribute || obj.send(attribute).nil?
              #LOGGER.debug("\n      ++++++++ Set attribute: #{attribute} with value:#{value}")
              obj.send("#{attribute}=", value) if obj.respond_to?("#{attribute}=")
            end
          end
          #LOGGER.debug("\n\n      - RETURN obj = #{obj.inspect}")
        rescue => e
          LOGGER.debug("\n\n ECCEZIONE - ONTOLOGIES_API - application_helper->populate_from_params: #{e.message} - \n #{e.backtrace.join("\n\t")}")
          raise e
        end
        obj
      end

      ##
      # Create an instance of +cls+ using provided +params+ to fill in attributes
      def instance_from_params(cls, params)
        n = cls.new
        populate_from_params(n, params)
      end

      ##
      # Serialize objects using a custom serializer that handles content negotiation
      # using the Accept header and "format" query string parameter
      # The method has two options parameters:
      #   +status (Fixnum)+: Status code to use in response
      #   +obj (Object)+: The object to serialize
      # Usage: +reply object+, +reply 201, object+
      def reply(*response)
        status = response.shift
        if !status.instance_of?(Fixnum)
          response.unshift status
          status = 200
        end

        obj = response.shift
        halt 404 if obj.nil?

        #LOGGER.debug("ONTOLOGIES_API - application_helper.rb - reply: obj = #{obj}")
        # Security check
        check_access(obj) if LinkedData.settings.enable_security

        # Slice or set check
        filter_for_slice(obj) if LinkedData.settings.enable_slices

        # Check for custom ontologies set by user
        filter_for_user_onts(obj)
        #LOGGER.debug("\n\nONTOLOGIES_API - application_helper.rb - reply: FILTERED obj = #{obj}\n\n")
        LinkedData::Serializer.build_response(@env, status: status, ld_object: obj)
      end

      ##
      # Override the halt method provided by Sinatra to set the response appropriately
      def halt(*response)
        status, headers, obj = nil
        obj = response.first if response.length == 1
        if obj.instance_of?(Fixnum)
          # This is a status-only response
          status = obj
          obj = nil
        end
        status, obj = response.first, response.last if response.length == 2
        status, headers, obj = response.first, response[1], response.last if response.length == 3
        if obj.is_a?(Rack::File) # Avoid the serializer when returning files
          super(response)
        else
          super(LinkedData::Serializer.build_response(@env, status: status, headers: headers, ld_object: obj))
        end
      end

      ##
      # Create an error response body by wrapping a message in a common hash structure
      # Call by providing an error code and then message or just a message:
      #   +error "Error message"+
      #   +error 400, "Error message"+
      def error(*message)
        status = message.shift
        if !status.instance_of?(Fixnum)
          message.unshift status
          status = 500
        end
        halt status, { :errors => message, :status => status }
      end

      ##
      # Look for the includes parameter and provide a formatted list of attributes
      def includes_param
        if @params["display"]
          return @params["display"].split(",").map {|e| e.to_sym}
        end
        Array.new
      end

      ##
      # Look for the ontologies acronym and give back a formatted list of ontolody id uris
      # This can be called without passing an argument and it will use the values from the current request
      def ontologies_param(params=nil)
        params ||= @params

        if params["ontologies"]
          # Get list
          ontologies = params["ontologies"].split(",").map {|o| o.strip}
          # When they aren't URIs, make them URIs
          ontologies.map! {|o| o.start_with?("http://") ? replace_url_prefix(o) : ontology_uri_from_acronym(o)}
          if ontologies.include? nil
            error 404, "The ontologies parameter `[#{params["ontologies"]}]` includes non-existent acronyms. Notice that acronyms are case sensitive."
          end
          return ontologies
        end
        Array.new
      end

      def restricted_ontologies(params=nil)
        params ||= @params

        found_onts = false
        if params["ontologies"] && !params["ontologies"].empty?
          onts = ontology_objects_from_params(params)
          found_onts = onts.length > 0
          Ontology.where.models(onts).include(*Ontology.access_control_load_attrs).all
        else
          if params["also_include_views"] == "true"
            onts = Ontology.where.include(Ontology.goo_attrs_to_load()).to_a
          else
            onts = Ontology.where.filter(Goo::Filter.new(:viewOf).unbound).include(Ontology.goo_attrs_to_load()).to_a
          end

          found_onts = onts.length > 0

          filter_for_slice(onts)
          filter_for_user_onts(onts)
        end
        onts = filter_access(onts)

        if found_onts && onts.empty?
          error 422, "No ontologies were found (either they weren't accessible to the user or there are none)"
        end

        return onts
      end

      def restricted_ontologies_to_acronyms(params=nil, onts=nil)
        onts ||= restricted_ontologies(params)
        return onts.map {|o| o.acronym }
      end

      def ontologies_param_to_acronyms(params=nil)
        ontResourceIds = ontologies_param(params)
        return ontResourceIds.map { |ontResourceId| ontResourceId.to_s.split('/')[-1]}
      end

      ##
      # Get semantic types parameter in the form [semantic_types=T099,T085,T345]
      def semantic_types_param(params=nil)
        params ||= @params

        if params["semantic_types"]
          semanticTypes = params["semantic_types"].split(",").map {|o| o.strip}
          return semanticTypes
        end
        Array.new
      end

      ##
      # Get cui parameter in the form [cui=C0302369,C0522224,C0176617]
      def cui_param(params=nil)
        params ||= @params
        if params["cui"]
          cui = params["cui"].split(",").map {|o| o.strip}
          return cui
        end
        Array.new
      end

      # validates month for 1-12 or 01-09
      def month_param(params=nil)
        params ||= @params
        if params["month"]
          month = params["month"].strip
          if %r{(?<month>^(0[1-9]|[1-9]|1[0-2])$)}x === month
            month.to_i
          end
        end
      end

      # validates year for starting with 1 or 2 and containing 4 digits
      def year_param(params=nil)
        params ||= @params
        if params["year"]
          year = params["year"].strip
          if %r{(?<year>^([1-2]\d{3})$)}x === year
            year.to_i
          end
        end
      end

      ##
      # Given an acronym (BRO), get the ontology URI (http://data.bioontology.org/ontologies/BRO)
      # @param acronym [String] the ontology acronym
      def ontology_uri_from_acronym(acronym)
        ontology_uri_acronym_map[acronym]
      end

      ##
      # Given a URI (http://data.bioontology.org/ontologies/BRO), get the ontology acronym (BRO)
      # @param uri [String] the ontology uri
      def acronym_from_ontology_uri(uri)
        acronym_ontology_uri_map[uri.to_s]
      end

      ##
      # Given an ontology acronym returns the ontology model.
      # Replies 404 if the ontology does not exist
      # Replies 400 if the ontology does not have a parsed submission
      def ontology_from_acronym(acronym)
        ontology = LinkedData::Models::Ontology.find(acronym).first
        error(404, "Ontology with acronym `#{acronym}` not found") if ontology.nil?
        submission = ontology.latest_submission
        error(400, "No parsed submissions for ontology with acronym `#{acronym}`") if submission.nil?
        return ontology
      end

      ##
      # From user params, return the ontology models.
      # Replies 404 if the ontology does not exist
      # Replies 400 if the ontology does not have a parsed submission
      def ontology_objects_from_params(params = nil)
        ontologies = Set.new(ontologies_param(params))
        all_onts = LinkedData::Models::Ontology.where.include(LinkedData::Models::Ontology.goo_attrs_to_load).to_a
        all_onts.select {|o| ontologies.include?(o.id.to_s)}
      end

      def ontology_uri_acronym_map
        cached_map = naive_expiring_cache_read(__method__)
        return cached_map if cached_map
        map = {}
        LinkedData::Models::Ontology.where.include(:acronym).all.each {|o| map[o.acronym] = o.id.to_s}
        naive_expiring_cache_write(__method__, map)
        map
      end

      def acronym_ontology_uri_map
        cached_map = naive_expiring_cache_read(__method__)
        return cached_map if cached_map
        map = {}
        LinkedData::Models::Ontology.where.include(:acronym).all.each {|o| map[o.id.to_s] = o.acronym}
        naive_expiring_cache_write(__method__, map)
        map
      end

      ##
      # Create a URI if the id is a URI, otherwise return unmodified
      def uri_as_needed(id)
        return id unless id.is_a?(String)
        id = replace_url_prefix(id)
        uri = RDF::URI.new(id)
        uri.valid? ? uri : id
      end

      ##
      # If the setting is enabled, replace the URL prefix with the proper id prefix
      # EX: http://stagedata.bioontology.org/ontologies/BRO would become http://data.bioontology.org/ontologies/BRO
      def replace_url_prefix(id)
        id = id.sub(LinkedData.settings.rest_url_prefix, LinkedData.settings.id_url_prefix) if LinkedData.settings.replace_url_prefix && id.start_with?(LinkedData.settings.rest_url_prefix)
        id
      end

      def retrieve_latest_submissions(options = {})
        # LOGGER.debug("API - application_helper -> retrieve_latest_submissions:")
        begin
          status = (options[:status] || "RDF").to_s.upcase
          include_ready = status.eql?("READY") ? true : false
          status = "RDF" if status.eql?("READY")
          any = true if status.eql?("ANY")
          include_views = options[:also_include_views] || false
          #includes = OntologySubmission.goo_attrs_to_load(includes_param)
          includes = OntologySubmission.goo_attrs_to_load(includes_param, -2) #modifica ecoportal: includo tutti gli attributi annidati
          # includes << {:creators => [:affiliations => [:affiliationIdentifierScheme, :affiliationIdentifier, :affiliation]]} #modifica ecoportal
          # includes << {:creators => [:creatorIdentifiers => [:nameIdentifierScheme, :schemeURI, :nameIdentifier]]} #modifica ecoportal
          includes << :submissionStatus unless includes.include?(:submissionStatus)
          #LOGGER.debug("     -> includes: #{includes.inspect}")
          if any
            submissions_query = OntologySubmission.where
          else
            submissions_query = OntologySubmission.where(submissionStatus: [ code: status])
          end

          submissions_query = submissions_query.filter(Goo::Filter.new(ontology: [:viewOf]).unbound) unless include_views
          submissions = submissions_query.include(includes).to_a

          # Figure out latest parsed submissions using all submissions
          latest_submissions = {}
          submissions.each do |sub|
            next if include_ready && !sub.ready?
            next if sub.ontology.nil?
            latest_submissions[sub.ontology.acronym] ||= sub
            latest_submissions[sub.ontology.acronym] = sub if sub.submissionId.to_i > latest_submissions[sub.ontology.acronym].submissionId.to_i
          end
        rescue => e
          LOGGER.debug("\n\n API - application_helper -> retrieve_latest_submissions: ECCEZIONE: #{e.message}\n#{e.backtrace.join("\n")}")
          raise e
        end
        
        return latest_submissions
      end

      def get_ontology_and_submission
        ont = Ontology.find(@params["ontology"])
              .include(:acronym, :administeredBy, :acl, :viewingRestriction)
              .include(submissions:
                       [:submissionId, submissionStatus: [:code], ontology: [:acronym], metrics: :classes])
                .first
        error(404, "Ontology '#{@params["ontology"]}' not found.") if ont.nil?
        check_access(ont) if LinkedData.settings.enable_security # Security check
        submission = nil
        if @params.include? "ontology_submission_id"
          submission = ont.submission(@params[:ontology_submission_id])
          if submission.nil?
            error 404,
               "You must provide an existing submission ID for the #{@params["acronym"]} ontology"
          end
        else
          submission = ont.latest_submission(status: [:RDF])
        end
        if submission.nil?
          error 404,  "Ontology #{@params["ontology"]} submission not found."
        end
        if !submission.ready?(status: [:RDF])
          error(404,
                "Ontology #{@params["ontology"]} submission i"+
                "#{submission.submissionId} has not been parsed.")
        end
        if submission.nil?
          if submission.nil?
            error 404, "Ontology #{@params["acronym"]} does not have any submissions"
          end
        end
        return ont, submission
      end

      def current_user
        env["REMOTE_USER"] || LinkedData::Models::User.new
      end

      def include_param_contains?(str)
        str = str.to_s unless str.is_a?(String)
        class_params_include = params["include_for_class"] && params["include_for_class"].include?(str.to_sym)
        params_include = params["display"] && params["display"].split(",").include?(str)
        return class_params_include || params_include
      end

      private

      def naive_expiring_cache_write(key, object, timeout = 60)
        @naive_expiring_cache ||= {}
        @naive_expiring_cache[key] = {timeout: Time.now + timeout, object: object}
      end

      def naive_expiring_cache_read(key)
        return if @naive_expiring_cache.nil?
        object = @naive_expiring_cache[key]
        return if object.nil?
        return if Time.now > object[:timeout]
        return object[:object]
      end

    end
  end
end

helpers Sinatra::Helpers::ApplicationHelper
