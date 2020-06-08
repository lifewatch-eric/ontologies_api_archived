class OntologiesController < ApplicationController

  namespace "/ontologies" do

    ##
    # Display all ontologies
    get do
      onts = nil
      check_last_modified_collection(Ontology)
      allow_views = params['also_include_views'] ||= false
      if allow_views
        onts = Ontology.where.include(Ontology.goo_attrs_to_load(includes_param)).to_a
      else
        onts = Ontology.where.filter(Goo::Filter.new(:viewOf).unbound).include(Ontology.goo_attrs_to_load(includes_param)).to_a
      end
      reply onts
    end

    ##
    # Display the most recent submission of the ontology
    get '/:acronym' do
      ont = Ontology.find(params["acronym"]).first
      error 404, "You must provide a valid `acronym` to retrieve an ontology" if ont.nil?
      check_last_modified(ont)
      ont.bring(*Ontology.goo_attrs_to_load(includes_param))
      reply ont
    end

    ##
    # Ontology latest submission
    get "/:acronym/latest_submission" do
      ont = Ontology.find(params["acronym"]).first
      error 404, "You must provide a valid `acronym` to retrieve an ontology" if ont.nil?
      include_status = params["include_status"]
      ont.bring(:acronym, :submissions)
      if include_status
        latest = ont.latest_submission(status: include_status.to_sym)
      else
        latest = ont.latest_submission(status: :any)
      end
      check_last_modified(latest) if latest
      latest.bring(*OntologySubmission.goo_attrs_to_load(includes_param, -2)) if latest
      reply(latest || {})
    end

    # Ontology latest submission datacite metadata as Json
    get "/:acronym/latest_submission/datacite_metadata_json" do
      begin
        ont = Ontology.find(params["acronym"]).first
        error 404, "You must provide a valid `acronym` to retrieve an ontology" if ont.nil?
        include_status = params["include_status"]
        ont.bring(:acronym, :submissions)
        if include_status
          latest = ont.latest_submission(status: include_status.to_sym)
        else
          latest = ont.latest_submission(status: :any)
        end
        check_last_modified(latest) if latest
        latest.bring(*OntologySubmission.goo_attrs_to_load(includes_param, -2)) if latest
        if(latest)
          return getDataciteMetadataJSON(latest)
        else
          reply {}
        end
      rescue => e
        LOGGER.debug("ONTOLOGIES_API - ontologies_controller.rb - datacite_metadata_json - ECCEZIONE : #{e.message}\n#{e.backtrace.join("\n")}")
        raise e
      end
    end


    get "/:acronym/latest_submission/ecoportal_metadata_json" do
      begin
        ont = Ontology.find(params["acronym"]).first
        error 404, "You must provide a valid `acronym` to retrieve an ontology" if ont.nil?
        include_status = params["include_status"]
        ont.bring(:acronym, :submissions)
        if include_status
          latest = ont.latest_submission(status: include_status.to_sym)
        else
          latest = ont.latest_submission(status: :any)
        end
        check_last_modified(latest) if latest
        latest.bring(*OntologySubmission.goo_attrs_to_load(includes_param, -2)) if latest
        if(latest)
          return getEcoportalMetadataJSON(latest)
        else
          reply {}
        end
      rescue => e
        LOGGER.debug("ONTOLOGIES_API - ontologies_controller.rb - datacite_metadata_json - ECCEZIONE : #{e.message}\n#{e.backtrace.join("\n")}")
        raise e
      end
    end

    # get "/:acronym/latest_submission/datacite_metadata_json2" do
    #   begin
    #     ont = Ontology.find(params["acronym"]).first
    #     error 404, "You must provide a valid `acronym` to retrieve an ontology" if ont.nil?
    #     include_status = params["include_status"]
    #     ont.bring(:acronym, :submissions)
    #     if include_status
    #       latest = ont.latest_submission(status: include_status.to_sym)
    #     else
    #       latest = ont.latest_submission(status: :any)
    #     end
    #     check_last_modified(latest) if latest
    #     latest.bring(*OntologySubmission.goo_attrs_to_load(includes_param, -2)) if latest
    #     if(latest)
    #       return latest.to_dataciteHash().to_json()
    #     else
    #       reply {}
    #     end
    #   rescue => e
    #     LOGGER.debug("ONTOLOGIES_API - ontologies_controller.rb - datacite_metadata_json - ECCEZIONE : #{e.message}\n#{e.backtrace.join("\n")}")
    #     raise e
    #   end
    # end

    ##
    # Create an ontology
    post do
      create_ontology
    end

    ##
    # Create an ontology with constructed URL
    put '/:acronym' do
      create_ontology
    end

    ##
    # Update an ontology
    patch '/:acronym' do
      # LOGGER.debug("\n==============================\n ONTOLOGIES_API - ontologies_controller -> PATCH action")
      #LOGGER.debug(" \n\n   > params: #{params.inspect}")
      ont = Ontology.find(params["acronym"]).include(Ontology.attributes).first
      error 422, "You must provide an existing `acronym` to patch" if ont.nil?

      populate_from_params(ont, params)
      if ont.valid?
        ont.save
        #LOGGER.debug(" \n\n   > ont: #{ont.inspect}")
      else
        LOGGER.debug("\n\n ERROR! ONTOLOGIES_API - ontologies_controller#PATCH : #{ont.errors.inspect} ")
        error 422, ont.errors
      end

      halt 204
    end

    ##
    # Delete an ontology and all its versions
    delete '/:acronym' do
      ont = Ontology.find(params["acronym"]).first
      error 422, "You must provide an existing `acronym` to delete" if ont.nil?
      ont.delete
      # update ontologies report file, if exists
      NcboCron::Models::OntologiesReport.new.delete_ontologies_from_report([params["acronym"]])
      halt 204
    end

    ##
    # Download the latest submission for an ontology
    get '/:acronym/download' do
      acronym = params["acronym"]
      ont = Ontology.find(acronym).include(Ontology.goo_attrs_to_load).first
      ont.bring(:viewingRestriction) if ont.bring?(:viewingRestriction)
      error 422, "You must provide an existing `acronym` to download" if ont.nil?
      check_access(ont)
      restricted_download = LinkedData::OntologiesAPI.settings.restrict_download.include?(acronym)
      error 403, "License restrictions on download for #{acronym}" if restricted_download && !current_user.admin?
      error 403, "Ontology #{acronym} is not accessible to your user" if ont.restricted? && !ont.accessible?(current_user)
      latest_submission = ont.latest_submission(status: :rdf)  # Should resolve to latest successfully loaded submission
      error 404, "There is no latest submission loaded for download" if latest_submission.nil?
      latest_submission.bring(:uploadFilePath)

      download_format = params["download_format"].to_s.downcase
      allowed_formats = ["csv", "rdf"]
      if download_format.empty?
        file_path = latest_submission.uploadFilePath
      elsif ([download_format] - allowed_formats).length > 0
        error 400, "Invalid download format: #{download_format}."
      elsif download_format.eql?("csv")
        latest_submission.bring(ontology: [:acronym])
        file_path = latest_submission.csv_path
      elsif download_format.eql?("rdf")
        file_path = latest_submission.rdf_path
      end

      if File.readable? file_path
        send_file file_path, :filename => File.basename(file_path)
      else
        error 500, "Cannot read latest submission upload file: #{file_path}"
      end
    end

    private

    def create_ontology
      params ||= @params

      # acronym must be well formed
      params['acronym'] = params['acronym'].upcase # coerce new ontologies to upper case

      # ontology acronym must be unique
      ont = Ontology.find(params['acronym']).first
      if ont.nil?
        ont = instance_from_params(Ontology, params)
      else
        error_msg = <<-ERR
        Ontology already exists, see #{ont.id}
        To add a new submission, POST to: /ontologies/#{params['acronym']}/submission.
        To modify the resource, use PATCH.
        ERR
        error 409, error_msg
      end

      # ontology name must be unique
      ont_names = Ontology.where.include(:name).to_a.map {|o| o.name }
      if ont_names.include?(ont.name)
        error 409, "Ontology name is already in use by another ontology."
      end

      if ont.valid?
        ont.save
      else
        error 422, ont.errors
      end

      reply 201, ont
    end
  end

  namespace "/ontologies_full" do
    ##
    # Display all ontologies with submissions and metrics
    get do
      # LOGGER.debug("\n=======================\n API - ontologies_controller -> ontologies_full: ")
      begin
        resp = []
        onts = nil
        allow_views = params['also_include_views'] ||= false

        if allow_views
          #LOGGER.debug("\n\n onts = Ontology.where.include(Ontology.goo_attrs_to_load(includes_param)).to_a")
          onts = Ontology.where.include(Ontology.goo_attrs_to_load(includes_param)).to_a
        else
          #LOGGER.debug("\n\n onts = Ontology.where.filter(Goo::Filter.new(:viewOf).unbound).include(Ontology.goo_attrs_to_load(includes_param)).to_a")
          onts = Ontology.where.filter(Goo::Filter.new(:viewOf).unbound).include(Ontology.goo_attrs_to_load(includes_param)).to_a
        end
        #LOGGER.debug("\n\n onts = #{onts.inspect}")
        options = {also_include_views: allow_views, status: (params["include_status"] || "ANY")}
        subs = retrieve_latest_submissions(options)
        #LOGGER.debug("\n\n subs = #{subs.inspect}")
        metrics_include = LinkedData::Models::Metric.goo_attrs_to_load(includes_param)
        #LOGGER.debug("\n\n subs = #{metrics_include.inspect}")
        #cancellami = LinkedData::Models::OntologySubmission.where.models(subs.values).include(metrics: metrics_include).all
        #LOGGER.debug("\n\n cancellami = #{cancellami.inspect}")
        onts.each do |ont|
          begin
            #LOGGER.debug("\n    - - - - -\n ont = #{ont.inspect}")
            sub = subs[ont.acronym]
            sub.ontology = nil if sub
            metrics = nil
            #LOGGER.debug("\n    - - - - -\n sub = #{sub.inspect}")
            begin
              metrics = sub.nil? ? nil : sub.metrics
            rescue
              metrics = nil
            end
            #LOGGER.debug("\n    - - - - -\n metrics = #{metrics.inspect}")
            resp << {ontology: ont, latest_submission: subs[ont.acronym], metrics: metrics}

            #LOGGER.debug("\n    - - - - -\n resp = #{resp.inspect}")
          rescue => e1
            LOGGER.debug("\n\n >>>>> ECCEZIONE - API - ontologies_controller -> ontologies_full: #{e1.message}\n#{e1.backtrace.join("\n")}")
            raise e1
          end
        end
      rescue => e
        LOGGER.debug("\n\n #ECCEZIONE - API - ontologies_controller -> ontologies_full: #{e.message}\n#{e.backtrace.join("\n")}")
        raise e
      end
      #LOGGER.debug("\n\n reply resp")
      reply resp
    end
  end

end
