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

    def cron_daemon_options
      cronSettingsJson = redis_cron.get "cron:daemon:options"
      error 500, "Unable to get CRON daemon options from Redis" if cronSettingsJson.nil?
      cronOptions = JSON.parse(cronSettingsJson, symbolize_names: true)
      cronOptions
    end

    def scheduled_jobs_map()
      cronOptions = cron_daemon_options

      {
        parse: {
          title: "parse semantic resources",
          enabled: cronOptions[:enable_processing] || false,
          scheduler_type: "every",
          schedule: "5m" # this is hardcoded in the scheduler class
        },
        pull: {
          title: "pull remote semantic resources",
          enabled: cronOptions[:enable_pull] || false,
          scheduler_type: "cron",
          schedule: cronOptions[:pull_schedule]
        },
        flush: {
          title: "flush classes",
          enabled: cronOptions[:enable_flush] || false,
          scheduler_type: "cron",
          schedule: cronOptions[:cron_flush]
        },
        warmq: {
          title: "warm up queries",
          enabled: cronOptions[:enable_warmq] || false,
          scheduler_type: "cron",
          schedule: cronOptions[:cron_warmq]
        },
        mapping_counts: {
          title: "mapping counts generation",
          enabled: cronOptions[:enable_mapping_counts] || false,
          scheduler_type: "cron",
          schedule: cronOptions[:cron_mapping_counts]
        },
        ontology_analytics: {
          title: "semantic resource analytics",
          enabled: cronOptions[:enable_ontology_analytics] || false,
          scheduler_type: "cron",
          schedule: cronOptions[:cron_ontology_analytics]
        },
        ontologies_report: {
          title: "semantic resources report",
          enabled: cronOptions[:enable_ontologies_report] || false,
          scheduler_type: "cron",
          schedule: cronOptions[:cron_ontologies_report]
        },
        index_synchronizer: {
          title: "index synchronization",
          enabled: cronOptions[:enable_index_synchronizer] || false,
          scheduler_type: "cron",
          schedule: cronOptions[:cron_index_synchronizer]
        },
        spam_deletion: {
          title: "spam deletion",
          enabled: cronOptions[:enable_spam_deletion] || false,
          scheduler_type: "cron",
          schedule: cronOptions[:cron_spam_deletion]
        },
        obofoundry_sync: {
          title: "OBO Foundry synchronization",
          enabled: cronOptions[:enable_obofoundry_sync] || false,
          scheduler_type: "cron",
          schedule: cronOptions[:cron_obofoundry_sync]
        }
      }
    end

    def stream_file(filename)
      if !File.exist? filename
        stream { |out| out << "" }
      else
        content_type "text/plain"
        stream do |out|
          File.open(filename, mode = "r") do |f|
            loop do
              chunk = f.read 4096
              if chunk.nil?
                break
              else
                out << chunk
              end
            end
          end
        end
      end
    end

    get "/scheduled_jobs" do
      reply MultiJson.dump scheduled_jobs_map
    end

    get "/scheduled_jobs/log" do
      logPath = cron_daemon_options[:log_path]
      stream_file(logPath)
    end

    get "/scheduled_jobs/:job/log" do
      scheduledJobs = scheduled_jobs_map
      jobName = params["job"]
      error 404, "You must provide a valid `job` to retrieve its log" unless scheduledJobs.has_key?(jobName.to_sym)

      logDirName = File.dirname(cron_daemon_options[:log_path])
      logFilename = "#{logDirName.chomp '/'}/scheduler-#{jobName.gsub '_', '-'}.log"

      stream_file(logFilename)
    end

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

    def redis_cron
      Redis.new(host: NcboCron.settings.redis_host, port: NcboCron.settings.redis_port, timeout: 30)
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
