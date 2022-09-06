require 'sinatra/base'
require_relative '../utils/utils'

module Sinatra
  module Helpers
    module AdminHelper
      
      
      ##
      # Create a JSON containing the list of the requests array for ADMIN PANEL
      def createIdentifierRequestHashList(objReqArray)
        begin
          array_included_keys = [
            :requestId,
            :status,
            :requestType,
            :requestedBy,
            :username,
            :email,
            :role,
            :requestDate,
            :processedBy,
            :processingDate,
            :message,
            :submission,
            :submissionId,
            :ontology,
            :acronym
          ]
          OntologiesApi::Utils.buildFilteredHash(objReqArray, array_included_keys)
        rescue => e
          LOGGER.debug("\n\n ECCEZIONE! ONTOLOGIES_API - AdminHelper - createIdentifierRequestHashList: #{e.message}\n#{e.backtrace.join("\n")}")
          raise e
        end
      end

    end
  end
end

helpers Sinatra::Helpers::AdminHelper
