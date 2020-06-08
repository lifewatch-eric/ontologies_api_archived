class IdentifierRequestsController < ApplicationController
  
  get "/ontologies/:acronym/identifier_requests" do
    
    acronym = params["acronym"]
    error 422, "You must provide an existing `acronym` " if acronym.nil? || acronym.empty?    
    identifiers = IdentifierRequest.where(submission: [ontology: [acronym: acronym]]).include(IdentifierRequest.goo_attrs_to_load(includes_param)).all    
    
    reply identifiers
  end

  namespace "/identifier_requests" do

    ##
    # Display all IdentifierRequest
    get do
      # LOGGER.debug("\n==============================\n ONTOLOGIES_API - IdentifierRequestsController -> GET /identifier_requests")
      idRequests = ""
      begin
        check_last_modified_collection(LinkedData::Models::IdentifierRequest)
        idRequests = IdentifierRequest.where.include(IdentifierRequest.goo_attrs_to_load(includes_param)).all
        idRequests = idRequests.select {|r| (!r.submission.nil? && !r.submission.ontology.nil? rescue false)}
        # LOGGER.debug("ONTOLOGIES_API - IdentifierRequestsController -> GET /identifier_requests: idRequests = #{idRequests.inspect}")
        reply idRequests
      rescue => e
        LOGGER.debug("\n\n ###### IdentifierRequestsController /identifier_requests ECCEZIONE: #{e.message}\n#{e.backtrace.join("\n")}")
        raise e
      end      
    end

    get "/all_doi_requests" do
      # LOGGER.debug("\n==============================\n ONTOLOGIES_API - IdentifierRequestsController -> GET ALL /identifier_requests/all_doi_requests")
      IdentifierReqObj = nil
      begin
        params["display_context"] = false
        params["display_links"] = false
        # LOGGER.debug("\n\n IdentifierRequestsController /identifier_requests: IdentifierRequest.goo_attrs_to_load(includes_param,-2): #{IdentifierRequest.goo_attrs_to_load(includes_param,-2)}")
        IdentifierReqArray = IdentifierRequest.where({requestType:"DOI_CREATE"}).or({requestType:"DOI_UPDATE"}).include(IdentifierRequest.goo_attrs_to_load(includes_param)).include(requestedBy: [:username, :email]).include(processedBy: [:username, :email]).include(submission: [:submissionId, :identifier, :identifierType, ontology: [:acronym]]).all
        #IdentifierReqArray = IdentifierReqArray.select {|idReqObj| !idReqObj.submission.nil? }
        # IdentifierReqArray.each do |r|
        #   r.bring(requestedBy: [:username, :email])
        #   r.bring(submission: [:submissionId, ontology: [:acronym]])
        # end
        # LOGGER.debug("\n\n ###### IdentifierRequestsController /identifier_requests: IdentifierReqArray = #{IdentifierReqArray.inspect}")
        
        
        reply IdentifierReqArray
      rescue => e
        LOGGER.debug("\n\n ###### IdentifierRequestsController /all_doi_requests ECCEZIONE: #{e.message}\n#{e.backtrace.join("\n")}")
        raise e
      end      
    end

    # get "/all_doi_requests2" do
    #   # LOGGER.debug("\n==============================\n ONTOLOGIES_API - IdentifierRequestsController -> GET ALL /identifier_requests/all_doi_requests")
    #   IdentifierReqObj = nil
    #   begin
    #     params["display_context"] = false
    #     params["display_links"] = false
    #     # LOGGER.debug("\n\n IdentifierRequestsController /identifier_requests: IdentifierRequest.goo_attrs_to_load(includes_param,-2): #{IdentifierRequest.goo_attrs_to_load(includes_param,-2)}")
    #     IdentifierReqArray = IdentifierRequest.where({requestType:"DOI_CREATE"}).or({requestType:"DOI_UPDATE"}).include(IdentifierRequest.goo_attrs_to_load(includes_param,-1)).include(requestedBy: [:username, :email]).include(processedBy: [:username, :email]).include(submission: [:submissionId, :identifier, :identifierType, ontology: [:acronym]]).all
    #     #IdentifierReqArray = IdentifierReqArray.select {|idReqObj| !idReqObj.submission.nil? }
    #     # IdentifierReqArray.each do |r|
    #     #   r.bring(requestedBy: [:username, :email])
    #     #   r.bring(submission: [:submissionId, ontology: [:acronym]])
    #     # end
    #     # LOGGER.debug("\n\n ###### IdentifierRequestsController /identifier_requests: IdentifierReqArray = #{IdentifierReqArray.inspect}")
        
        
    #     reply IdentifierReqArray
    #   rescue => e
    #     LOGGER.debug("\n\n ###### IdentifierRequestsController /all_doi_requests2 ECCEZIONE: #{e.message}\n#{e.backtrace.join("\n")}")
    #     raise e
    #   end      
    # end

    # get "/all_doi_requests3" do
    #   # LOGGER.debug("\n==============================\n ONTOLOGIES_API - IdentifierRequestsController -> GET ALL /identifier_requests/all_doi_requests")
    #   IdentifierReqObj = nil
    #   begin
    #     params["display_context"] = false
    #     params["display_links"] = false
    #     # LOGGER.debug("\n\n IdentifierRequestsController /identifier_requests: IdentifierRequest.goo_attrs_to_load(includes_param,-2): #{IdentifierRequest.goo_attrs_to_load(includes_param,-2)}")
    #     IdentifierReqArray = IdentifierRequest.where({requestType:"DOI_CREATE"}).or({requestType:"DOI_UPDATE"}).include(IdentifierRequest.goo_attrs_to_load(includes_param,-1)).include(requestedBy: [:username, :email]).include(processedBy: [:username, :email]).include(submission: [:submissionId, :identifier, :identifierType, ontology: [:acronym]]).all
    #     IdentifierReqArray = IdentifierReqArray.select {|idReqObj| !idReqObj.submission.nil?}
    #     # IdentifierReqArray.each do |r|
    #     #   r.bring(requestedBy: [:username, :email])
    #     #   r.bring(submission: [:submissionId, ontology: [:acronym]])
    #     # end
    #     # LOGGER.debug("\n\n ###### IdentifierRequestsController /identifier_requests: IdentifierReqArray = #{IdentifierReqArray.inspect}")
        
        
    #     reply IdentifierReqArray
    #   rescue => e
    #     LOGGER.debug("\n\n ###### IdentifierRequestsController /all_doi_requests3 ECCEZIONE: #{e.message}")
    #     raise e
    #   end      
    # end

    # get "/all_doi_requests4" do
    #   # LOGGER.debug("\n==============================\n ONTOLOGIES_API - IdentifierRequestsController -> GET ALL /identifier_requests/all_doi_requests4")
    #   IdentifierReqObj = nil
    #   begin
    #     IdentifierReqArray = IdentifierRequest.where({requestType:"DOI_CREATE"}).or({requestType:"DOI_UPDATE"}).include(IdentifierRequest.goo_attrs_to_load(includes_param,-1)).all
    #     #IdentifierReqArray = IdentifierReqArray.select {|idReqObj| !idReqObj.submission.nil? }
    #     # LOGGER.debug("\n\n ###### IdentifierRequestsController /identifier_requests: IdentifierReqArray = #{IdentifierReqArray.inspect}")
    #     reply IdentifierReqArray
    #   rescue => e
    #     LOGGER.debug("\n\n ###### IdentifierRequestsController /all_doi_requests4 ECCEZIONE: #{e.message}\n#{e.backtrace.join("\n")}")
    #     raise e
    #   end      
    # end


    # get "/all_doi_requests5" do
    #   # LOGGER.debug("\n==============================\n ONTOLOGIES_API - IdentifierRequestsController -> GET ALL /identifier_requests/all_doi_requests5")
    #   IdentifierReqObj = nil
    #   begin
    #     IdentifierReqArray = IdentifierRequest.where({requestType:"DOI_CREATE"}).or({requestType:"DOI_UPDATE"}).include(IdentifierRequest.goo_attrs_to_load(includes_param,-2)).all
    #     #IdentifierReqArray = IdentifierReqArray.select {|idReqObj| !idReqObj.submission.nil? }
    #     # LOGGER.debug("\n\n ###### IdentifierRequestsController /identifier_requests: IdentifierReqArray = #{IdentifierReqArray.inspect}")
    #     reply IdentifierReqArray
    #   rescue => e
    #     LOGGER.debug("\n\n ###### IdentifierRequestsController /all_doi_requests5 ECCEZIONE: #{e.message}\n#{e.backtrace.join("\n")}")
    #     raise e
    #   end      
    # end

    ##
    # Display a IdentifierRequest with a specific requestId
    get "/:requestId" do
      # LOGGER.debug("\n==============================\n ONTOLOGIES_API - IdentifierRequestsController -> GET /identifier_requests/:requestId -> #{params["requestId"]}")
      IdentifierReqObj = nil
      begin
        IdentifierReqObj = IdentifierRequest.find(params["requestId"]).include(IdentifierRequest.goo_attrs_to_load(includes_param,-2)).first
        # LOGGER.debug("\n\n ###### IdentifierRequestsController /identifier_requests: IdentifierReqObj = #{IdentifierReqObj.inspect}")
        reply IdentifierReqObj
      rescue => e
        LOGGER.debug("\n\n ###### IdentifierRequestsController /identifier_requests ECCEZIONE: #{e.message}\n#{e.backtrace.join("\n")}")
        raise e
      end      
    end

    get "/:requestId/submission" do
      begin
        # IdentifierReqObj = IdentifierRequest.find(params["requestId"]).first        
        # IdentifierReqObj.bring(submission: OntologySubmission.goo_attrs_to_load(includes_param))
        # LOGGER.debug("\n\n ###### IdentifierRequestsController /identifier_requests: IdentifierReqObj = #{IdentifierReqObj.inspect}")
        # reply IdentifierReqObj.submission.sort {|a,b| b.submissionId.to_i <=> a.submissionId.to_i }

        # IdentifierReqObj = IdentifierRequest.find(params["requestId"]).include(IdentifierRequest.goo_attrs_to_load(includes_param)).include(requestedBy: [:username, :email], processedBy: [:username, :email], submission: [:submissionId, :identifier, :identifierType, ontology: [:acronym]]).first        
        IdentifierReqObj = IdentifierRequest.find(params["requestId"]).include(IdentifierRequest.goo_attrs_to_load(includes_param)).first        
        # LOGGER.debug("\n\n ###### IdentifierRequestsController /identifier_requests: IdentifierReqObj 1= #{IdentifierReqObj.inspect}")
        IdentifierReqObj.bring(submission: OntologySubmission.goo_attrs_to_load(includes_param))
        # LOGGER.debug("\n\n ###### IdentifierRequestsController /identifier_requests: IdentifierReqObj 2= #{IdentifierReqObj.inspect}")
        reply IdentifierReqObj.submission

      rescue => e
        LOGGER.debug("\n\n ###### IdentifierRequestsController /identifier_requests/:requestId/submission ECCEZIONE: #{e.message}\n#{e.backtrace.join("\n")}")
        raise e
      end   
    end

    get "/:requestId/requestedBy" do
      begin
     
        IdentifierReqObj = IdentifierRequest.find(params["requestId"]).include(IdentifierRequest.goo_attrs_to_load(includes_param)).first        
        # LOGGER.debug("\n\n ###### IdentifierRequestsController /identifier_requests/:requestId/requestedBy: IdentifierReqObj 1= #{IdentifierReqObj.inspect}")
        IdentifierReqObj.bring(requestedBy: User.goo_attrs_to_load(includes_param))
        # LOGGER.debug("\n\n ###### IdentifierRequestsController /identifier_requests/:requestId/requestedBy: IdentifierReqObj 2= #{IdentifierReqObj.inspect}")
        reply IdentifierReqObj.requestedBy

      rescue => e
        LOGGER.debug("\n\n ###### IdentifierRequestsController /identifier_requests/:requestId/requestedBy ECCEZIONE: #{e.message}\n#{e.backtrace.join("\n")}")
        raise e
      end   
    end

    get "/:requestId/processedBy" do
      begin        
        IdentifierReqObj = IdentifierRequest.find(params["requestId"]).include(IdentifierRequest.goo_attrs_to_load(includes_param)).first        
        # LOGGER.debug("\n\n ###### IdentifierRequestsController /identifier_requests/:requestId/processedBy: IdentifierReqObj 1= #{IdentifierReqObj.inspect}")
        IdentifierReqObj.bring(processedBy: User.goo_attrs_to_load(includes_param))
        # LOGGER.debug("\n\n ###### IdentifierRequestsController /identifier_requests/:requestId/processedBy: IdentifierReqObj 2= #{IdentifierReqObj.inspect}")
        reply IdentifierReqObj.processedBy

      rescue => e
        LOGGER.debug("\n\n ###### IdentifierRequestsController /identifier_requests/:requestId/processedBy ECCEZIONE: #{e.message}\n#{e.backtrace.join("\n")}")
        raise e
      end   
    end

   ##
    # Create a IdentifierRequest
    post do
      # LOGGER.debug("\n==============================\n ONTOLOGIES_API - IdentifierRequestsController -> POST /identifier_requests -> create a new identifier_requests")

      #error 422, "You must provide a valid `requestId` to create a new IdentifierRequests" if (params["requestId"].nil? || params["requestId"].empty?)
      _identifierRequest=create_identifierRequest()
      #_identifierRequest.bring(requestedBy: [:username, :email, role: [:role]])
      _identifierRequest.bring(requestedBy: [:username, :email])
      _identifierRequest.bring(submission: [:submissionId, :identifier, :identifierType, ontology: [:acronym,:administeredBy, :acl, :viewingRestriction]])
      # LOGGER.debug(" \n\n   >  identifierRequest Created =#{_identifierRequest.inspect}")      
      reply 201, _identifierRequest
    end


    # ##
    # # Create an ontology with constructed URL
    # put '/:acronym' do
      
    # end

    ##
    # Update an IdentifierRequest
    patch '/:requestId' do
      # LOGGER.debug("\n==============================\n ONTOLOGIES_API - IdentifierRequestsController -> PATCH /identifier_requests -> update the identifier_requests with id #{params["requestId"]}")
      begin
        _identifierRequest = IdentifierRequest.find(params["requestId"]).first
        error 422, "You must provide an existing `requestId` to patch" if _identifierRequest.nil?

        populate_from_params(_identifierRequest, params)
        if _identifierRequest.valid?
          _identifierRequest.save
          #LOGGER.debug(" \n\n   > ont: #{ont.inspect}")
        else
          error 422, _identifierRequest.errors
        end

        halt 204
      rescue => e
        LOGGER.debug("\n\n !ECCEZIONE! IdentifierRequestsController -> PATCH /identifier_requests : #{e.message}\n#{e.backtrace.join("\n")}")
        raise e
      end      
    end

    
    # Delete ALL IdentifierRequests
    delete '/all' do
      begin
        # LOGGER.debug("\n\n ===========\n ONTOLOGIES_API - IdentifierRequestsController -> DELETE ALL ")
        arrayIdentifierRequest = IdentifierRequest.where.all
        error 422, "No elements was found" if arrayIdentifierRequest.nil?
        # LOGGER.debug(" ONTOLOGIES_API - IdentifierRequestsController -> DELETE ALL arrayIdentifierRequest:#{arrayIdentifierRequest.inspect} ")
        arrayIdentifierRequest.each do |e|
          e.delete
        end
        halt 204
      rescue => e
        LOGGER.debug("\n\n !ECCEZIONE! IdentifierRequestsController -> DELETE ALL : #{e.message}\n#{e.backtrace.join("\n")}")
        raise e
      end   
    end


    ##
    # Delete an IdentifierRequest
    delete '/:requestId' do
      begin
        # LOGGER.debug("\n\n ===========\n ONTOLOGIES_API - IdentifierRequestsController -> DELETE  with id: #{params["requestId"]}")
        _identifierRequest = IdentifierRequest.find(params["requestId"]).first
        error 422, "You must provide an existing `requestId` to delete" if _identifierRequest.nil?
        _identifierRequest.delete      
        halt 204
      rescue => e
        LOGGER.debug("\n\n !ECCEZIONE! IdentifierRequestsController -> DELETE /identifier_requests : #{e.message}\n#{e.backtrace.join("\n")}")
        raise e
      end   
    end


    # #################################################
    # #   AJAX REQUEST
    # #################################################

    # post '/cancelIdentifierRequest' do
    #   begin        
    #     # LOGGER.debug("\n\n IdentifierRequestsController.rb - identifier_requests/cancelIdentifierRequest:  requestId = #{params["requestId"]} - current_user=#{current_user}")
      
    #     error 400, "You must provide a `requestId`" if params["requestId"].nil?
    #     # error 400, "You must provide the new resquest `status`" if params["status"].nil?
    #     # error 400, "You must provide a valid status" if ['REJECTED', 'SATISFIED'].includes?(params["status"])      

    #     req = IdentifierRequest.find(params["requestId"]).include(IdentifierRequest.goo_attrs_to_load(includes_param)).first
    #     error 400, "DOI request not found" if req.nil?

    #     if current_user.admin? || checkWritePermission(req, current_user)
    #       req.send("status=", 'CANCELED')
    #       req.send("processedBy=", current_user)
    #       req.send("processingDate=", DateTime.now)
          
    #       # LOGGER.debug("\n\n IdentifierRequestsController.rb - identifier_requests/cancelIdentifierRequest - BEFORE SAVE")
    #       if req.valid?
    #         req.save           
    #       else
    #         LOGGER.debug("\n\n ERRORE IdentifierRequestsController - cancelIdentifierRequest: object IdentifierRequest not valid : #{req.errors.inspect}")
    #         error 422, req.errors
    #       end

    #     end
    #     # LOGGER.debug("\n\n IdentifierRequestsController.rb - identifier_requests/cancelIdentifierRequest - SAVED")
    #     reply 200, { :data => "The request has been canceled" }
    #   rescue => e
    #     LOGGER.debug("\n\n !ECCEZIONE! IdentifierRequestsController -> cancelIdentifierRequest /identifier_requests : #{e.message}\n#{e.backtrace.join("\n")}")
    #     raise e
    #   end        
    # end

    
  end

end