require 'sinatra/base'
require_relative '../utils/utils'

module Sinatra
  module Helpers
    module OntologySubmissionHelper
      def getDataciteMetadataJSON(sub)
        begin
          # LOGGER.debug("ONTOLOGIES_API - ontology_submissions_helper.rb - getDataciteMetadataJSON")          
          json = OntologiesApi::Utils.getDataciteMetadataJSON(sub)
          json        
        rescue => e
          LOGGER.debug("ONTOLOGIES_API - ontology_submissions_helper.rb - getDataciteMetadataJSON - ECCEZIONE : #{e.message}\n#{e.backtrace.join("\n")}")
          raise e
        end
      end


    end

  end
end

helpers Sinatra::Helpers::OntologySubmissionHelper
