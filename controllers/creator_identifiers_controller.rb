class CreatorIdentifiersController < ApplicationController

  namespace "/creator_identifiers" do

    ##
    # Display all CreatorIdentifier
    get do
      identifiers = ""
      begin
        check_last_modified_collection(LinkedData::Models::CreatorIdentifier)
        identifiers = CreatorIdentifier.where.include(CreatorIdentifier.goo_attrs_to_load(includes_param)).all
      rescue => e
        #LOGGER.debug("\n\n ###### CreatorIdentifierController /creator_identifier ECCEZIONE: #{e.message}")
        raise e
      end
      reply identifiers
    end

    get "/:id" do
      identifiers = ""
        begin
          identifiers = CreatorIdentifier.find(params[:id]).include(CreatorIdentifier.goo_attrs_to_load(includes_param)).all          
        rescue => e
          #LOGGER.debug("\n\n ###### CreatorIdentifierController /creator_identifier ECCEZIONE: #{e.message}")
          raise e
        end
        reply identifiers
    end   

  end

  # namespace "/creator_identifiers_2" do

  #   get do
  #     identifiers = ""
  #     begin
  #       identifiers = CreatorIdentifier.where(nameIdentifierScheme: "prova2").all
  #     rescue => e
  #       #LOGGER.debug("\n\n ###### CreatorIdentifierController /creator_identifier_2 ECCEZIONE: #{e.message}")
  #       raise e
  #     end
  #     reply identifiers
  #   end     
  # end

  # namespace "/creator_identifiers_3" do

  #   get do
  #     identifiers = ""
  #     begin
  #       identifiers = CreatorIdentifier.where(nameIdentifierScheme: "prova2").include(CreatorIdentifier.goo_attrs_to_load(includes_param)).all
  #     rescue => e
  #       #LOGGER.debug("\n\n ###### CreatorIdentifierController /creator_identifier_3 ECCEZIONE: #{e.message}")
  #       raise e
  #     end
  #     reply identifiers
  #   end     
  # end

  # namespace "/creator_identifiers-add" do
  #   get do
  #     begin
  #       creatorIdentifierObj = LinkedData::Models::CreatorIdentifier.new(nameIdentifierScheme: "prova2", schemeURI: "prova22", nameIdentifier: "prova222")

  #       #LOGGER.debug("\n\n creatorIdentifiersController /creator_identifiers-add BEFORE SAVING creatorIdentifierObj: #{creatorIdentifierObj.inspect}")
        
  #       savedObj = creatorIdentifierObj.save();

  #       #LOGGER.debug("\n\n creatorIdentifiersController /creator_identifiers-add AFTER SAVING creatorIdentifierObj saved: #{savedObj.inspect}")
  #       reply savedObj
  #     rescue => e
  #       #LOGGER.debug("\n\n CreatorController /creators-add ECCEZIONE: #{e.message}")
  #       raise e
  #     end
  #   end
  # end

end
