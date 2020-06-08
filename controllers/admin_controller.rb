require 'multi_json'
require 'open-uri'
require 'net/http'
require 'uri'
require 'cgi'

class AdminController < ApplicationController

  namespace "/admin" do
    before {
      if LinkedData.settings.enable_security && (!env["REMOTE_USER"] || !env["REMOTE_USER"].admin?)
        error 403, "Access denied"
      end
    }

    # TODO: remove this endpoint. It's termporary to test the update check functionality
    # get "/latestversion" do
    #   iid = params["iid"]
    #   ver = params["version"]
    #
    #   latest_ver_info = {
    #       update_version: "2.5RC3", #"2.6RC1",
    #       update_available: true,
    #       notes: "blah blah and more"
    #   }
    #   reply MultiJson.dump latest_ver_info
    # end

    get "/update_info" do
      um = NcboCron::Models::UpdateManager.new
      um.check_for_update if params["force_check"].eql?('true')
      reply um.update_info
    end

    get "/update_check_enabled" do
      reply NcboCron.settings.enable_update_check ? 'true' : 'false'
    end

    get "/objectspace" do
      GC.start
      gdb_objs = Hash.new 0
      ObjectSpace.each_object {|o| gdb_objs[o.class] += 1}
      obj_usage = gdb_objs.to_a.sort {|a,b| b[1]<=>a[1]}
      MultiJson.dump obj_usage
    end

    get "/ontologies/:acronym/log" do
      ont_report = NcboCron::Models::OntologiesReport.new.ontologies_report(false)
      log_path = ont_report[:ontologies].has_key?(params["acronym"].to_sym) ? "#{LinkedData.settings.repository_folder}/#{ont_report[:ontologies][params["acronym"].to_sym][:logFilePath]}" : ''
      log_contents = ''

      if !log_path.empty? && File.file?(log_path)
        file = File.open(log_path, "rb")
        log_contents = file.read
        file.close
      end
      reply log_contents
    end

    put "/ontologies/:acronym" do
      actions = NcboCron::Models::OntologySubmissionParser::ACTIONS.dup
      actions[:all] = false
      error_message = "You must provide valid action(s) for ontology processing. Valid actions: ?actions=#{actions.keys.join(",")}"
      actions_param = params["actions"]
      error 404, error_message unless actions_param
      action_arr = actions_param.split(",")
      actions.each { |k, _| actions[k] = action_arr.include?(k.to_s) ? true : false }
      error 404, error_message if actions.values.select { |v| v === true }.empty?
      ont = Ontology.find(params["acronym"]).first
      error 404, "You must provide a valid `acronym` to retrieve an ontology" if ont.nil?
      ont.bring(:acronym, :submissions)
      latest = ont.latest_submission(status: :any)
      error 404, "Ontology #{params["acronym"]} contains no submissions" if latest.nil?
      check_last_modified(latest)
      latest.bring(*OntologySubmission.goo_attrs_to_load(includes_param))
      NcboCron::Models::OntologySubmissionParser.new.queue_submission(latest, actions)
      halt 204
    end

    # # Process a DOI request
    # put "/satisfy_doi_request/:id" do
    #   #retreive the action (process od reject)
    #   error_message = "You must provide valid id for the request you want to process."
    #   actions_param = params["actions"]
    #   error 404, error_message unless actions_param

    #   doiRequest = IdentifierRequest.find(params["id"]).include(IdentifierRequest.goo_attrs_to_load(includes_param,-2)).first
    #   # if I didn't find the DOI request
    #   error 404, "You must provide a valid `requestId` to retrieve the Request" if doiRequest.nil?


    #   #find the submission related to the request
    #   submission = doiRequest.submission
    #   error_message = "You must provide valid id for the request you want to process."
    #   # if I didn't find the submission in request
    #   error 404, "The request doesn't have associated an ontology submission" if submission.nil?

    #   case doiRequest.requestType
    #   when IdentifierRequestType.DOI_CREATE
    #     response = CreateDoiInformationToDatacite()
    #     if response.status == 'success'
    #       new_doi = response.data.doi
    #       submission.identifier = new_doi
    #       submission.identifierType = "DOI"
    #       submission.save()
    #       doiRequest.status = IdentifierRequestStatus.SATISFIED
    #       doiRequest.save()
    #     else
    #       error_message = response.error
    #     end
    #   when IdentifierRequestType.DOI_UPDATE
    #     response = UpdateDoiInformationToDatacite()
    #     if response.status == 'success'
    #       doiRequest.status = IdentifierRequestStatus.SATISFIED
    #       doiRequest.save()
    #     else
    #       error_message = response.error
    #     end
    #   end
    #   error 500, "Error while request processing: #{error_message}" unless error_message.nil?

    #   halt 204
    # end


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
      latest.bring(*OntologySubmission.goo_attrs_to_load(includes_param)) if latest
      reply(latest || {})
    end

    get "/ontologies_report" do
      suppress_error = params["suppress_error"].eql?('true') # default = false
      reply NcboCron::Models::OntologiesReport.new.ontologies_report(suppress_error)
    end

    post "/ontologies_report" do
      ontologies = ontologies_param_to_acronyms(params)
      args = {name: "ontologies_report", message: "refreshing ontologies report"}
      process_id = process_long_operation(900, args) do |args|
        NcboCron::Models::OntologiesReport.new.refresh_report(ontologies)
      end
      reply(process_id: process_id)
    end

    get "/ontologies_report/:process_id" do
      process_id = MultiJson.load(redis.get(params["process_id"]))

      if process_id.nil?
        error 404, "Process id #{params["process_id"]} does not exit"
      else
        if process_id === "done"
          reply NcboCron::Models::OntologiesReport.new.ontologies_report(false)
        else
          # either "processing" OR errors {errors: ["errorA", "errorB"]}
          reply process_id
        end
      end
    end

    post "/clear_goo_cache" do
      redis_goo.flushdb
      halt 204
    end

    post "/clear_http_cache" do
      redis_http.flushdb
      halt 204
    end

    #=============================================================
    #                   DOI REQUESTs MANAGEMENT
    #=============================================================

    # get "/doi_requests_list" do
    #   IdentifierReqObj = nil
    #   begin
    #     LOGGER.debug("\n\n  - - - - - \n ONTOLOGIES_API - admin_controller /doi_requests_list")
    #     IdentifierReqArray = IdentifierRequest.where({requestType:"DOI_CREATE"}).or({requestType:"DOI_UPDATE"}).include(IdentifierRequest.goo_attrs_to_load(includes_param)).include(requestedBy: [:username, :email], processedBy: [:username, :email], submission: [:submissionId, :identifier, :identifierType, ontology: [:acronym]]).all
    #     IdentifierReqArray = IdentifierReqArray.select {|idReqObj| (!idReqObj.submission.nil?)}

    #     IdentifierReqArray = IdentifierReqArray.each do |r| 
    #       r.bring(submission: OntologySubmission.goo_attrs_to_load(includes_param))
    #       r.bring(requestedBy: User.goo_attrs_to_load(includes_param))
    #       r.bring(processedBy: User.goo_attrs_to_load(includes_param))
    #     end

    #     params["display_context"] = false
    #     params["display_links"] = false
    #     LOGGER.debug("\n ONTOLOGIES_API - admin_controller /doi_requests_list: IdentifierReqArray = #{IdentifierReqArray.inspect}")
    #     reply IdentifierReqArray
    #   rescue => e
    #     LOGGER.debug("\n\n ###### admin_controller /doi_requests_list ECCEZIONE: #{e.message}")
    #     raise e
    #   end      
    # end

    get "/doi_requests_list" do
      IdentifierReqObj = nil
      begin
        # LOGGER.debug("\n\n  - - - - - \n ONTOLOGIES_API - admin_controller /doi_requests_list")
        IdentifierReqArray = IdentifierRequest.where({requestType:"DOI_CREATE"}).or({requestType:"DOI_UPDATE"}).include(IdentifierRequest.goo_attrs_to_load(includes_param)).include(requestedBy: [:username, :email], processedBy: [:username, :email], submission: [:submissionId, :identifier, :identifierType, ontology: [:acronym]]).all
        IdentifierReqArray = IdentifierReqArray.select {|idReqObj| (!idReqObj.submission.nil? && !idReqObj.submission.ontology.nil? rescue false)}

        IdentifierReqArray = IdentifierReqArray.each do |r| 
          r.bring(submission: OntologySubmission.goo_attrs_to_load(includes_param))
          r.bring(requestedBy: User.goo_attrs_to_load(includes_param))
          r.bring(processedBy: User.goo_attrs_to_load(includes_param))
        end

        response = createIdentifierRequestHashList(IdentifierReqArray)
        # LOGGER.debug("\n ONTOLOGIES_API - admin_controller /doi_requests_list: response = #{response}")
        reply response
      rescue => e
        LOGGER.debug("\n\n ###### admin_controller /doi_requests_list ECCEZIONE:  #{e.message}\n#{e.backtrace.join("\n")}")
        raise e
      end      
    end

    #Searches and returns the request with the id passed as parameter
    get "/doi_request/:id" do
      error 400, "You must provide the id of the request" if params[:id].nil?
      IdentifierReqObj = nil
      begin
        # LOGGER.debug("\n\n  - - - - - \n ONTOLOGIES_API - admin_controller /doi_request/:id - id = #{params[:id]}")
        IdentifierReqArray = IdentifierRequest.where({requestType:"DOI_CREATE"}).or({requestType:"DOI_UPDATE"}).include(IdentifierRequest.goo_attrs_to_load(includes_param)).include(requestedBy: [:username, :email], processedBy: [:username, :email], submission: [:submissionId, :identifier, :identifierType, ontology: [:acronym]]).all
        IdentifierReqArray = IdentifierReqArray.select {|idReqObj| (!idReqObj.submission.nil? && idReqObj.requestId == params[:id])}

        error 500, "request not found" if IdentifierReqArray.nil? || IdentifierReqArray.length == 0
        error 500, "ERROR! More than one request was found" if IdentifierReqArray.length > 1

        IdentifierReqArray = IdentifierReqArray.each do |r| 
          r.bring(submission: OntologySubmission.goo_attrs_to_load(includes_param))
          r.bring(requestedBy: User.goo_attrs_to_load(includes_param))
          r.bring(processedBy: User.goo_attrs_to_load(includes_param))
        end

        response = createIdentifierRequestHashList(IdentifierReqArray)
        # LOGGER.debug("\n ONTOLOGIES_API - admin_controller //doi_request/:id: response = #{response[0]}")
        reply response[0]
      rescue => e
        LOGGER.debug("\n\n ###### admin_controller /doi_request/:id ECCEZIONE:  #{e.message}\n#{e.backtrace.join("\n")}")
        raise e
      end      
    end

    # get "/ontology_submissions_with_identifier/:ont_acronym" do
    #   submissions = nil
    #   acronym = params["ont_acronym"]
    #   begin
    #     f = (!Goo::Filter.new(:identifier).nil?)
    #       .or(Goo::Filter.new(:identifier)!= "")
    #     submissions = OntologySubmission.where({ontology.acronym:acronym}).and({identifier:"DOI_UPDATE"}).include(IdentifierRequest.goo_attrs_to_load(includes_param)).include(requestedBy: [:username], processedBy: [:username], submission: [:submissionId, :identifier, :identifierType, ontology: [:acronym]]).all
    #     IdentifierReqArray = IdentifierReqArray.select {|idReqObj| (!idReqObj.submission.nil?}
    #     params["display_context"] = false
    #     params["display_links"] = false
       
    #     reply IdentifierReqArray
    #   rescue => e
    #     LOGGER.debug("\n\n ###### admin_controller /doi_requests_list ECCEZIONE: #{e.message}")
    #     raise e
    #   end      
    # end

    #=============================================================
    #                   PRIVATE METHODS
    #=============================================================

    private

    def process_long_operation(timeout, args)
      process_id = "#{Time.now.to_i}_#{args[:name]}"
      redis.setex process_id, timeout, MultiJson.dump("processing")
      proc = Proc.new {
        error = {}
        begin
          yield(args)
        rescue Exception => e
          msg = "Error #{args[:message]} - #{e.class}: #{e.message}"
          puts "#{msg}\n#{e.backtrace.join("\n\t")}"
          error[:errors] = [msg]
        end
        redis.setex process_id, timeout, MultiJson.dump(error.empty? ? "done" : error)
      }

      fork = true # set to false for testing
      if fork
        pid = Process.fork do
          proc.call
        end
        Process.detach(pid)
      else
        proc.call
      end
      process_id
    end

    def redis
      Redis.new(host: Annotator.settings.annotator_redis_host, port: Annotator.settings.annotator_redis_port, timeout: 30)
    end

    def redis_goo
      Redis.new(host: LinkedData.settings.goo_redis_host, port: LinkedData.settings.goo_redis_port, timeout: 30)
    end

    def redis_http
      Redis.new(host: LinkedData.settings.http_redis_host, port: LinkedData.settings.http_redis_port, timeout: 30)
    end

    private 

    def render_json(json, options={})
    callback, variable = params[:callback], params[:variable]
    response = begin
      if callback && variable
        "var #{variable} = #{json};\n#{callback}(#{variable});"
      elsif variable
        "var #{variable} = #{json};"
      elsif callback
        "#{callback}(#{json});"
      else
        json
      end
    end
    render({:content_type => "application/json", :text => response}.merge(options))
  end

  end
end
