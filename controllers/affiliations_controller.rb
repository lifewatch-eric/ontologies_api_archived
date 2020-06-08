class AffiliationsController < ApplicationController

  namespace "/affiliations" do

    ##
    # Display all Affiliations
    get do
      affiliations = ""
      begin
        check_last_modified_collection(LinkedData::Models::Affiliation)
        affiliations = Affiliation.where.include(Affiliation.goo_attrs_to_load(includes_param)).all
      rescue => e
        #LOGGER.debug("\n\n ###### AffiliationController /affiliations ECCEZIONE: #{e.message}")
        raise e
      end
      reply affiliations
    end 
    
    get "/:id" do
      affiliations = ""
        begin
          affiliations = Affiliation.find(params[:id]).include(Affiliation.goo_attrs_to_load(includes_param)).all          
        rescue => e
          #LOGGER.debug("\n\n ###### AffiliationController /affiliations ECCEZIONE: #{e.message}")
          raise e
        end
        reply affiliations
    end
  end

  
  # namespace "/affiliations-add" do
  #   get do
  #     begin
  #       affiliationObj = LinkedData::Models::Affiliation.new(affiliationIdentifierScheme: "aff_1", affiliationIdentifier: "aff_11", affiliation: "aff_111")

  #       LOGGER.debug("\n\n AffiliationsController /affiliations-add BEFORE SAVING affiliationObj: #{affiliationObj.inspect}")
        
  #       savedObj = affiliationObj.save();

  #       LOGGER.debug("\n\n AffiliationsController /affiliations-add AFTER SAVING affiliationObj saved: #{savedObj.inspect}")
  #       reply savedObj
  #     rescue => e
  #       LOGGER.debug("\n\n AffiliationsController /affiliations-add ECCEZIONE: #{e.message}")
  #       raise e
  #     end
  #   end
  # end

end
