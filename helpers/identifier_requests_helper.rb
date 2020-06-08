require 'sinatra/base'
require_relative '../utils/utils'

module Sinatra
  module Helpers
    module IdentifierRequestsHelper
     
     
      ##
      # Create a new OntologySubmission object based on the request data
      def create_identifierRequest()
        begin
          params = @params       
          # LOGGER.debug("\n\n ONTOLOGIES_API - IdentifierRequestsHelper - create_identifierRequest: params: #{params}")
          # Create OntologySubmission
          params["display"] = "all"
          identifierRequestObj = instance_from_params(IdentifierRequest, params)
          identifierRequestObj.requestId = IdentifierRequest.identifierRequest_id_generator() if (identifierRequestObj.requestId.nil? || identifierRequestObj.requestId.empty?)
          identifierRequestObj.save
          identifierRequestObj
        rescue => e
          LOGGER.debug("\n\n ECCEZIONE! ONTOLOGIES_API - IdentifierRequestsHelper - create_identifierRequest: #{e.message}\n#{e.backtrace.join("\n")}")
          raise e
        end
      end

      # # ##
      # # # Checks if the user has write permission for the identifier request
      # def checkWritePermission(identifierReqObj, user)
      #   begin
      #     # LOGGER.debug("\n\n ONTOLOGIES_API - IdentifierRequestsHelper - identifierReqObj: #{identifierReqObj} - user= #{user.inspect}")
      #     if !identifierReqObj.nil?
      #       identifierReqObj.bring(submission: OntologySubmission.goo_attrs_to_load(includes_param))
      #       if !identifierReqObj.submission.nil? && !identifierReqObj.submission.ontology.nil?
      #         return identifierReqObj.submission.ontology.accessible?(user)
      #       end
      #     end
      #     return false  
      #   rescue => e
      #     LOGGER.debug("\n\n ECCEZIONE! ONTOLOGIES_API - IdentifierRequestsHelper - checkWritePermission: #{e.message}\n#{e.backtrace.join("\n")}")
      #     raise e
      #   end
      # end      

    end
  end
end

helpers Sinatra::Helpers::IdentifierRequestsHelper
