require 'sinatra/base'
require_relative '../utils/utils'

module Sinatra
  module Helpers
    module OntologyHelper
      ##
      # Create a new OntologySubmission object based on the request data
      def create_submission(ont)
        params = @params

        submission_id = ont.next_submission_id

        # Create OntologySubmission
        ont_submission = instance_from_params(OntologySubmission, params)
        ont_submission.ontology = ont
        ont_submission.submissionId = submission_id

        # Get file info
        add_file_to_submission(ont, ont_submission)

        # Add new format if it doesn't exist
        if ont_submission.hasOntologyLanguage.nil?
          error 422, "You must specify the ontology format using the `hasOntologyLanguage` parameter" if params["hasOntologyLanguage"].nil? || params["hasOntologyLanguage"].empty?
          ont_submission.hasOntologyLanguage = OntologyFormat.find(params["hasOntologyLanguage"]).first
        end

        if ont_submission.valid?
          ont_submission.save
          cron = NcboCron::Models::OntologySubmissionParser.new
          cron.queue_submission(ont_submission, {all: true})
        else
          error 400, ont_submission.errors
        end

        ont_submission
      end

      ##
      # Checks to see if the request has a file attached
      def request_has_file?
        @params.any? {|p,v| v.instance_of?(Hash) && v.key?(:tempfile) && v[:tempfile].instance_of?(Tempfile)}
      end

      ##
      # Looks for a file that was included as a multipart in a request
      def file_from_request
        @params.each do |param, value|
          if value.instance_of?(Hash) && value.has_key?(:tempfile) && value[:tempfile].instance_of?(Tempfile)
            return value[:filename], value[:tempfile]
          end
        end
        return nil, nil
      end

      ##
      # Add a file to the submission if a file exists in the params
      def add_file_to_submission(ont, submission)
        # LOGGER.debug(" ONTOLOGIES_API - ontology_helper->add_file_to_submission:")
        filename, tmpfile = file_from_request
        if tmpfile
          if filename.nil?
            error 400, "Failure to resolve ontology filename from upload file."
          end
          # Copy tmpfile to appropriate location
          ont.bring(:acronym) if ont.bring?(:acronym)
          # Ensure the ontology acronym is available
          if ont.acronym.nil?
            error 500, "Failure to resolve ontology acronym"
          end
          file_location = OntologySubmission.copy_file_repository(ont.acronym, submission.submissionId, tmpfile, filename)
          submission.uploadFilePath = file_location
        end
        return filename, tmpfile
      end

      def getDataciteMetadataJSON(sub)
        begin          
          json = OntologiesApi::Utils.getDataciteMetadataJSON(sub)
          json        
        rescue => e
          LOGGER.debug("ONTOLOGIES_API - ontology_helper.rb - getDataciteMetadataJSON - ECCEZIONE : #{e.message}\n#{e.backtrace.join("\n")}")
          raise e
        end
      end

      
      def getEcoportalMetadataJSON(sub)
        begin          
          json = OntologiesApi::Utils.getEcoportalMetadataJSON(sub)
          json        
        rescue => e
          LOGGER.debug("ONTOLOGIES_API - ontology_helper.rb - getEcoportalMetadataJSON - ECCEZIONE : #{e.message}\n#{e.backtrace.join("\n")}")
          raise e
        end
      end
    end
  end
end

helpers Sinatra::Helpers::OntologyHelper
