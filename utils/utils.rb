# --- NEW ECOPORTAL class-----
# Utility class 
module OntologiesApi  
  class Utils    
    #Symbolize the keys recursively for the object passed as parameter
    # Es. {"a" => "aaa", "b" =>  {"b1" => "bbb1", "b2" => "bbb2"}}  
    # becomes  {:a => "aaa", :b =>  {:b1 => "bbb1", :b2 => "bbb2"}}
    def self.recursive_symbolize_keys(obj, exclude_nil_value = false, exclude_empty_array = false, excluded_keys = [])
      # LOGGER.debug("ONTOLOGIES_API_RUBY_CLIENT: LinkedData::Client::Utils -> recursive_symbolize_keys CALL:")
      if obj.is_a?Array
        # LOGGER.debug(" OBJ is an Array")
        obj.map do |e|
          val = (e.to_h == {}) ? e : e.to_h
          recursive_symbolize_keys(val, exclude_nil_value, exclude_empty_array, excluded_keys)
        end
      else
        obj = obj.respond_to?(:to_hash) ? obj.to_hash : obj
        {}.tap do |h|
          obj.each do |key, value|
            # LOGGER.debug("ONTOLOGIES_API_RUBY_CLIENT: LinkedData::Client::Utils -> recursive_symbolize_keys [key,value] = [#{key}, #{value}]  - key.to_sym= #{key.to_sym}")
            next if excluded_keys.include?(key)
            next if (exclude_nil_value && value.nil?)
            next if (exclude_empty_array && value.is_a?(Array) && value.length == 0)
            h[key.to_sym] = map_value(value, exclude_nil_value, exclude_empty_array, excluded_keys)
          end
        end
      end
    end
  
    def self.map_value(thing, exclude_nil_value = false, exclude_empty_array =false, excluded_keys = [])
      # LOGGER.debug("ONTOLOGIES_API_RUBY_CLIENT: LinkedData::Client::Utils -> map_value: \n    > thing = #{thing}")
      case thing
      when LinkedData::Models::Base
        recursive_symbolize_keys(thing, exclude_nil_value, exclude_empty_array, excluded_keys)
      when Hash
        # LOGGER.debug(" > thing is HASH")
        recursive_symbolize_keys(thing, exclude_nil_value, exclude_empty_array, excluded_keys)
      when Array
        # LOGGER.debug(" > thing is Array")
        thing.map { |v| map_value(v, exclude_nil_value, exclude_empty_array,excluded_keys) }
      when OpenStruct
        # LOGGER.debug(" > thing is OpenStruct")
        recursive_symbolize_keys(thing.to_h, exclude_nil_value, exclude_empty_array, excluded_keys)      
      else
        # LOGGER.debug(" > thing type is not recognized")
        thing
      end
    end

    # UTILITY: be an object comparables with another one, indipendently the order of its fields or the order of 
    # its array elements
    # For each array in the object (Hash or OpenStruct) or nested into subobject, this method order the elements.
    # That permits to compare two objects (Hash or OpenStruct). 
    #  Es. 
    #     {:a => [3,1,2], :b =>  {:b1 => [30,10,50], :b2 => [300,100,500]}}  
    #     becomes  {:a => [1,2,3], :b =>  {:b1 => [10,30,50], :b2 => [100,300,500]}} 
    #
    # In case the elements of array are hashs, then it orders them by their hash value
    def self.order_inner_array_elements(obj, exclude_nil_value = false, exclude_empty_array =false, excluded_keys = [])
      if obj.is_a?Array
        obj.map do |e|
          val = (e.to_h == {}) ? e : e.to_h
          order_inner_array_elements(val, exclude_nil_value, exclude_empty_array, excluded_keys)
        end
        #obj.map{|e| order_inner_array_elements(e.to_h, exclude_nil_value, excluded_keys)}
      else
        obj = obj.respond_to?(:to_hash) ? obj.to_hash : obj
        {}.tap do |h|
          obj.each do |key, value|
            next if excluded_keys.include?(key)
            next if (exclude_nil_value && value.nil?)
            next if (exclude_empty_array && value.is_a?(Array) && value.length == 0)
            v = map_ordered_value(value, exclude_nil_value, exclude_empty_array,excluded_keys)      
            h[key.to_sym] = v
          end
        end
      end        
    end
  
    def self.map_ordered_value(thing, exclude_nil_value = false, exclude_empty_array =false, excluded_keys = [])
      case thing
      when LinkedData::Models::Base
        recursive_symbolize_keys(thing, exclude_nil_value, excluded_keys)
      when Hash
        result = order_inner_array_elements(thing, exclude_nil_value, exclude_empty_array, excluded_keys)
      when Array    
        result = thing.map do |v|
          case v    
          when Hash, Array, OpenStruct
            map_ordered_value(v, exclude_nil_value, exclude_empty_array, excluded_keys)
          else
            v
          end
        end
        result = result.sort_by{|e| e.is_a?(Hash) ? e.hash : e}    
      when OpenStruct
        result = order_inner_array_elements(thing.to_h, exclude_nil_value, exclude_empty_array, excluded_keys)
      else
        result = thing
      end
      result
    end



    ############## DATACITE METADATA JSON ##############
    
    
    #
    def self.getHashWithFilteredKeys(sub, exclude_nil_value = false, exclude_empty_array =false, include_only_keys = [])
      #LOGGER.debug("ONTOLOGIES_API - utils.rb -> getHashWithFilteredKeys CALL:")
      begin
        if sub.is_a?Array
          ## LOGGER.debug(" OBJ is an Array")
          sub.map do |e|
            val = e.respond_to?(:to_hash) ? e.to_hash : ((e.to_h == {}) ? e : e.to_h)
            getHashWithFilteredKeys(val, exclude_nil_value, exclude_empty_array, include_only_keys)
          end
        else
          sub = sub.respond_to?(:to_hash) ? sub.to_hash : sub
          {}.tap do |h|
            sub.each do |key, value|
              # LOGGER.debug("ONTOLOGIES_API_RUBY_CLIENT: LinkedData::Client::Utils -> getHashWithFilteredKeys [key,value] = [#{key}, #{value}]  - key.to_sym= #{key.to_sym}")
              next if include_only_keys.length>0 && !include_only_keys.include?(key)
              next if (exclude_nil_value && value.nil?)
              next if (exclude_empty_array && value.is_a?(Array) && value.length == 0)
              h[key.to_sym] = map_HashWithFilteredKeys(value, exclude_nil_value, exclude_empty_array, include_only_keys)
            end
          end
        end
      rescue => e
        LOGGER.debug("ONTOLOGIES_API - utils.rb -> getHashWithFilteredKeys - ECCEZIONE : #{e.message}\n#{e.backtrace.join("\n")}")
        raise e
      end

    end

    def self.map_HashWithFilteredKeys(thing, exclude_nil_value = false, exclude_empty_array =false, include_only_keys = [])
      # LOGGER.debug("ONTOLOGIES_API_RUBY_CLIENT: LinkedData::Client::Utils -> map_HashWithFilteredKeys: \n    > thing = #{thing}")
      case thing
      when LinkedData::Models::Base
        getHashWithFilteredKeys(thing, exclude_nil_value, exclude_empty_array, include_only_keys)
      when Hash
        getHashWithFilteredKeys(thing, exclude_nil_value, exclude_empty_array, include_only_keys)
      when Array
        thing.map { |v| map_HashWithFilteredKeys(v, exclude_nil_value, exclude_empty_array,include_only_keys) }
      when OpenStruct
        getHashWithFilteredKeys(thing.to_h, exclude_nil_value, exclude_empty_array, include_only_keys)
      when DateTime
        thing.to_s
      else
        thing
      end
    end


    def self.getDataciteMetadataJSON(ontologySubmissionObj)
      begin
        # LOGGER.debug("ONTOLOGIES_API - utils.rb - CALL getDataciteMetadataJSON - ontologySubmissionObj : #{ontologySubmissionObj.inspect}")
        included_keys = [
          :version,
          :publication,
          :description,
          :identifier,
          :identifierType,
          :creators,
          :creatorName,
          :nameType,
          :givenName,
          :familyName,
          :creatorIdentifiers,
          :nameIdentifier,
          :nameIdentifierScheme,
          :schemeURI,
          :affiliations,
          :affiliation,
          :affiliationIdentifier,
          :affiliationIdentifierScheme,
          :titles,
          :title,
          :titleType,
          :publisher,
          :publicationYear,
          :resourceType,
          :resourceTypeGeneral
        ]
        objDC = getHashWithFilteredKeys(ontologySubmissionObj,true, true, included_keys)

        #Transform hash attributes to be compatible with the Datacite Standard
        
        # NAME IDENTIFIER
        unless objDC[:creators].nil?
          objDC[:creators].map do |c|
            c[:nameIdentifiers] = c.delete :creatorIdentifiers if(c[:creatorIdentifiers])
          end
        end

        #if(!objDC[:identifierType].nil? && [LinkedData::Models::IdentifierRequestType.DOI_CREATE, LinkedData::Models::IdentifierRequestType.DOI_UPDATE].include? objDC[:identifierType])
        if(!objDC[:identifierType].nil? && objDC[:identifierType].start_with?('DOI'))        
          objDC[:doi] = objDC.delete :identifier if(objDC[:identifier])
        end
        objDC.delete :identifierType
        objDC.delete :identifier

        # TYPES
        objDC[:types] = {
          resourceTypeGeneral: objDC[:resourceTypeGeneral],
				  resourceType: objDC[:resourceType]
        }
        objDC.delete :resourceTypeGeneral
        objDC.delete :resourceType

        # URL
        objDC[:url] = objDC.delete :publication if(objDC[:publication])
        # LOGGER.debug("(*) ONTOLOGIES_API - utils.rb - getDataciteMetadataJSON - hash datacite : #{objDC.inspect}")
        objDC.to_json
      rescue => e
        LOGGER.debug("ONTOLOGIES_API - utils.rb - getDataciteMetadataJSON - ECCEZIONE : #{e.message}\n#{e.backtrace.join("\n")}")
        raise e
      end
    end


    def self.getEcoportalMetadataJSON(ontologySubmissionObj)
      begin
        # LOGGER.debug("ONTOLOGIES_API - utils.rb - CALL getDataciteMetadataJSON - ontologySubmissionObj : #{ontologySubmissionObj.inspect}")
        included_keys = [
          :ontology,
          :acronym,
          :identifier,
          :identifierType,
          :name,
          :contact,
          :email,
          :status,
          :homepage,
          :documentation,
          :version,
          :publication,
          :description,         
          :creators,
          :creatorName,
          :nameType,
          :givenName,
          :familyName,
          :creatorIdentifiers,
          :nameIdentifier,
          :nameIdentifierScheme,
          :schemeURI,
          :affiliations,
          :affiliation,
          :affiliationIdentifier,
          :affiliationIdentifierScheme,
          :hasOntologyLanguage,
          :titles,
          :title,
          :titleType,
          :publisher,
          :publicationYear,
          :resourceType,
          :resourceTypeGeneral
        ]
        objDC = getHashWithFilteredKeys(ontologySubmissionObj,true, true, included_keys)

        #Transform hash attributes to be compatible with the Datacite Standard
        
        # NAME IDENTIFIER
        unless objDC[:creators].nil?
          objDC[:creators].map do |c|
            c[:nameIdentifiers] = c.delete :creatorIdentifiers if(c[:creatorIdentifiers])
          end
        end
        
        #DOI
        if(objDC[:identifierType] == 'None')        
          objDC.delete(:identifier)
        end
       
        #FORMAT
        objDC[:format] = objDC.delete :hasOntologyLanguage if(objDC[:hasOntologyLanguage])


        # TYPES
        objDC[:types] = {
          resourceTypeGeneral: objDC[:resourceTypeGeneral],
				  resourceType: objDC[:resourceType]
        }
        objDC.delete :resourceTypeGeneral
        objDC.delete :resourceType

        # URL
        objDC[:url] = objDC.delete :publication if(objDC[:publication])
        # LOGGER.debug("(*) ONTOLOGIES_API - utils.rb - getDataciteMetadataJSON - hash datacite : #{objDC.inspect}")
        objDC.to_json
      rescue => e
        LOGGER.debug("ONTOLOGIES_API - utils.rb - getDataciteMetadataJSON - ECCEZIONE : #{e.message}\n#{e.backtrace.join("\n")}")
        raise e
      end
    end

    # Build a Hash with only the specified Keys
    def self.buildFilteredHash(obj, array_included_keys)
      begin
        # LOGGER.debug("ONTOLOGIES_API - utils.rb - CALL buildFilteredHash - sub : #{obj.inspect}")
        error 400, 'You must specify the keys you want to include into json' if array_included_keys.nil? || array_included_keys.empty?
        objDC = getHashWithFilteredKeys(obj,true, true, array_included_keys)
        objDC
      rescue => e
        LOGGER.debug("ONTOLOGIES_API - utils.rb - buildFilteredHash - ECCEZIONE : #{e.message}\n#{e.backtrace.join("\n")}")
        raise e
      end
    end

  end
end
