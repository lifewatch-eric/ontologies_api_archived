class OntologySubmissionsController < ApplicationController
  get "/submissions" do
    check_last_modified_collection(LinkedData::Models::OntologySubmission)
    #using appplication_helper method
    options = {also_include_views: params["also_include_views"], status: (params["include_status"] || "ANY")}
    reply retrieve_latest_submissions(options).values
  end

  ##
  # Create a new submission for an existing ontology
  post "/submissions" do
    ont = Ontology.find(uri_as_needed(params["ontology"])).include(Ontology.goo_attrs_to_load).first
    error 422, "You must provide a valid `acronym` to create a new submission" if ont.nil?
    reply 201, create_submission(ont)
  end

  namespace "/ontologies/:acronym/submissions" do

    ##
    # Display all submissions of an ontology
    get do
      # LOGGER.debug("\n\n**********************\n ONTOLOGIES_API - ontology_submission_controller-> GET [namespace /ontologies/:acronym/submissions]")
      ont = Ontology.find(params["acronym"]).include(:acronym).first
      error 422, "Ontology #{params["acronym"]} does not exist" unless ont
      check_last_modified_segment(LinkedData::Models::OntologySubmission, [ont.acronym])
      # ont.bring(submissions: OntologySubmission.goo_attrs_to_load(includes_param))
      ont.bring(submissions: OntologySubmission.goo_attrs_to_load(includes_param,-2)) # modifica ecoportal
      reply ont.submissions.sort {|a,b| b.submissionId.to_i <=> a.submissionId.to_i }  # descending order of submissionId
    end

    ##
    # Create a new submission for an existing ontology
    post do
      # LOGGER.debug(" \n\n=============================\n ONTOLOGIES_API - ontology_submission_controller-> POST [namespace /ontologies/:acronym/submissions]: ")
      ont = Ontology.find(params["acronym"]).include(Ontology.attributes).first
      error 422, "You must provide a valid `acronym` to create a new submission" if ont.nil?
      _a_submission=create_submission(ont)
      # LOGGER.debug(" \n\n   >  _a_submission=#{_a_submission.inspect}")
      reply 201, _a_submission
    end

    ##
    # Display a submission
    get '/:ontology_submission_id' do
      ont = Ontology.find(params["acronym"]).include(:acronym).first
      check_last_modified_segment(LinkedData::Models::OntologySubmission, [ont.acronym])
      ont.bring(:submissions)
      ont_submission = ont.submission(params["ontology_submission_id"])
      error 404, "`submissionId` not found" if ont_submission.nil?
      #ont_submission.bring(*OntologySubmission.goo_attrs_to_load(includes_param))
      ont_submission.bring(*OntologySubmission.goo_attrs_to_load(includes_param, -2)) # modifica ecoportal
      reply ont_submission
    end

    # Ontology a submission datacite metadata as Json
    get "/:ontology_submission_id/datacite_metadata_json" do
      begin
        # LOGGER.debug("ONTOLOGIES_API - ontology_submissions_controller.rb - datacite_metadata_json")
        ont = Ontology.find(params["acronym"]).include(:acronym).first
        check_last_modified_segment(LinkedData::Models::OntologySubmission, [ont.acronym])
        ont.bring(:submissions)
        ont_submission = ont.submission(params["ontology_submission_id"])
        error 404, "`submissionId` not found" if ont_submission.nil?
        #ont_submission.bring(*OntologySubmission.goo_attrs_to_load(includes_param))
        ont_submission.bring(*OntologySubmission.goo_attrs_to_load(includes_param, -2)) # modifica ecoportal        
        return getDataciteMetadataJSON(ont_submission)        
      rescue => e
        LOGGER.debug("ONTOLOGIES_API - ontology_submissions_controller.rb - datacite_metadata_json - ECCEZIONE : #{e.message}\n#{e.backtrace.join("\n")}")
        raise e
      end
    end

    ##
    # Update an existing submission of an ontology
    REQUIRES_REPROCESS = ["prefLabelProperty", "definitionProperty", "synonymProperty", "authorProperty", "classType", "hierarchyProperty", "obsoleteProperty", "obsoleteParent"]
    patch '/:ontology_submission_id' do
      # LOGGER.debug("\n==============================\n ONTOLOGIES_API - ontology_submission_controller->PATCH : UPDATE EXISTING SUBMISSION \n params:#{params.inspect}")
      #LOGGER.debug(" \n\n   > params: #{params.inspect}")
      ont = Ontology.find(params["acronym"]).first
      error 422, "You must provide an existing `acronym` to patch" if ont.nil?
      #LOGGER.debug("\n\n   > ont: #{ont.inspect}")
      
      submission = ont.submission(params[:ontology_submission_id])
      error 422, "You must provide an existing `submissionId` to patch" if submission.nil?
      #LOGGER.debug("\n\n   > submission: #{submission.inspect}")
     
      submission.bring(*OntologySubmission.attributes)
      #LOGGER.debug("\n\n   > submission (AFTER BRING): #{submission.inspect}")

      populate_from_params(submission, params)
      #LOGGER.debug("\n\n   > submission (AFTER populate_from_params): #{submission.inspect}")
      add_file_to_submission(ont, submission)
      #LOGGER.debug("\n\n   > submission (AFTER add_file_to_submission): #{submission.inspect}\n-------------------------------------\n")

      if submission.valid?
        submission.save
        #LOGGER.debug("\n\n   > submission (AFTER save): #{submission.inspect}")
        if (params.keys & REQUIRES_REPROCESS).length > 0 || request_has_file?
          cron = NcboCron::Models::OntologySubmissionParser.new
          cron.queue_submission(submission, {all: true})
        end
      else
        error 422, submission.errors
      end

      halt 204
    end

    ##
    # Delete a specific ontology submission
    delete '/:ontology_submission_id' do
      ont = Ontology.find(params["acronym"]).first
      error 422, "You must provide an existing `acronym` to delete" if ont.nil?
      submission = ont.submission(params[:ontology_submission_id])
      error 422, "You must provide an existing `submissionId` to delete" if submission.nil?
      submission.delete
      halt 204
    end

    ##
    # Download a submission
    get '/:ontology_submission_id/download' do
      acronym = params["acronym"]
      submission_attributes = [:submissionId, :submissionStatus, :uploadFilePath, :pullLocation]
      included = Ontology.goo_attrs_to_load.concat([submissions: submission_attributes])
      ont = Ontology.find(acronym).include(included).first
      ont.bring(:viewingRestriction) if ont.bring?(:viewingRestriction)
      error 422, "You must provide an existing `acronym` to download" if ont.nil?
      check_access(ont)
      ont_restrict_downloads = LinkedData::OntologiesAPI.settings.restrict_download
      error 403, "License restrictions on download for #{acronym}" if ont_restrict_downloads.include? acronym
      submission = ont.submission(params['ontology_submission_id'].to_i)
      error 404, "There is no such submission for download" if submission.nil?
      file_path = submission.uploadFilePath

      download_format = params["download_format"].to_s.downcase
      allowed_formats = ["csv", "rdf"]
      if download_format.empty?
        file_path = submission.uploadFilePath
      elsif ([download_format] - allowed_formats).length > 0
        error 400, "Invalid download format: #{download_format}."
      elsif download_format.eql?("csv")
        if ont.latest_submission.id != submission.id
          error 400, "Invalid download format: #{download_format}."
        else
          latest_submission.bring(ontology: [:acronym])
          file_path = submission.csv_path
        end
      elsif download_format.eql?("rdf")
        file_path = submission.rdf_path
      end

      if File.readable? file_path
        send_file file_path, :filename => File.basename(file_path)
      else
        error 500, "Cannot read submission upload file: #{file_path}"
      end
    end

    ##
    # Download a submission diff file
    get '/:ontology_submission_id/download_diff' do
      acronym = params["acronym"]
      submission_attributes = [:submissionId, :submissionStatus, :diffFilePath]
      ont = Ontology.find(acronym).include(:submissions => submission_attributes).first
      error 422, "You must provide an existing `acronym` to download" if ont.nil?
      ont.bring(:viewingRestriction)
      check_access(ont)
      ont_restrict_downloads = LinkedData::OntologiesAPI.settings.restrict_download
      error 403, "License restrictions on download for #{acronym}" if ont_restrict_downloads.include? acronym
      submission = ont.submission(params['ontology_submission_id'].to_i)
      error 404, "There is no such submission for download" if submission.nil?
      file_path = submission.diffFilePath
      if File.readable? file_path
        send_file file_path, :filename => File.basename(file_path)
      else
        error 500, "Cannot read submission diff file: #{file_path}"
      end
    end

    def delete_submissions(startId, endId)
      startId.upto(endId + 1) do |i|
        sub = LinkedData::Models::OntologySubmission.find(RDF::URI.new("http://data.bioontology.org/ontologies/MS/submissions/#{i}")).first
        sub.delete if sub
      end
    end

  end


end
