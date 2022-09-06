class CreatorsController < ApplicationController

  namespace "/creators" do

    ##
    # Display all ontologies
    get do
      creators = ""
      begin
        creators = Creator.where.include(Creator.goo_attrs_to_load(includes_param)).all
      rescue => e
        #LOGGER.debug("\n\n CreatorController /creators ECCEZIONE: #{e.message}")
        raise e
      end
      reply creators
    end
  end

  # namespace "/creators-where1" do
  #   get do
  #     creators = ""
  #     begin
  #       match={ nameType: "Personal",
  #               givenName: "Carlo",
  #               familyName: "Santo",
  #               creatorName: "Carlo Santo",
  #               affiliations: [
  #                 { 
  #                   affiliationIdentifierScheme: "aff_scheme_carlo2",
  #                   affiliationIdentifier: "aff_indent_carlo",
  #                   affiliation: "aff_name_carlo"
  #                 }
  #               ],
  #               creatorIdentifiers: [
  #                 {
  #                   nameIdentifierScheme: "orcid3",
  #                   schemeURI: "www.orcid3.org",
  #                   nameIdentifier: "id_carlo_santo"
  #                 }
  #               ]
  #             }
  #       creators = Creator.where(match).include(Creator.goo_attrs_to_load(includes_param, -2)).all
  #       #creators = Creator.where(match).first
  #     rescue => e
  #       #LOGGER.debug("\n\n CreatorController /creators-where1 ECCEZIONE: #{e.message}")
  #       raise e
  #     end
  #     reply creators
  #   end
  # end

  # namespace "/creators-where2" do
  #   get do
  #     creators = ""
  #     begin
  #       match={:givenName=>"pippo", :familyName=>"bianchi", :creatorIdentifiers=>[{:nameIdentifierScheme=>"aa", :schemeURI=>"bb", :nameIdentifier=>"cc"}]}
  #       creators = Creator.where(match).include(Creator.goo_attrs_to_load(includes_param)).all
  #       #creators = Creator.where(match).first
  #     rescue => e
  #       #LOGGER.debug("\n\n CreatorController /creators-where2 ECCEZIONE: #{e.message}")
  #       raise e
  #     end
  #     reply creators
  #   end
  # end

  # namespace "/creators-where3" do
  #   get do
  #     creators = ""
  #     begin
  #       creators = Creator.where(:givenName=>"pippo", :familyName=>"bianchi", :creatorIdentifiers=>[{:nameIdentifierScheme=>"a", :schemeURI=>"b", :nameIdentifier=>"c"}, {:nameIdentifierScheme=>"aa", :schemeURI=>"bb", :nameIdentifier=>"cc"}]).include(Creator.goo_attrs_to_load(includes_param)).all
  #     rescue => e
  #       #LOGGER.debug("\n\n CreatorController /creators-where3 ECCEZIONE: #{e.message}")
  #       raise e
  #     end
  #     reply creators
  #   end
  # end

  # namespace "/creators-where4" do
  #   get do
  #     creators = ""
  #     begin
  #       creators = Creator.where(:givenName=>"pippo", :familyName=>"bianchi").include(Creator.goo_attrs_to_load(includes_param)).all
  #     rescue => e
  #       #LOGGER.debug("\n\n CreatorController /creators-where4 ECCEZIONE: #{e.message}")
  #       raise e
  #     end
  #     reply creators
  #   end
  # end

  # namespace "/creators-where5" do
  #   get do
  #     creators = ""
  #     begin
  #       creators = Creator.where(:givenName=>"pippo", :creatorIdentifiers=>[{:nameIdentifierScheme=>"a", :schemeURI=>"b", :nameIdentifier=>"c"}]).include(Creator.goo_attrs_to_load(includes_param)).all
  #     rescue => e
  #       #LOGGER.debug("\n\n CreatorController /creators-where3 ECCEZIONE: #{e.message}")
  #       raise e
  #     end
  #     reply creators
  #   end
  # end

  # namespace "/creators-where6" do
  #   get do
  #     creators = ""
  #     begin
  #       creators = Creator.where(:givenName=>"pippo", :creatorIdentifiers=>[{:nameIdentifierScheme=>"a", :schemeURI=>"b", :nameIdentifier=>"c"}]).include(Creator.goo_attrs_to_load(includes_param)).all
  #     rescue => e
  #       #LOGGER.debug("\n\n CreatorController /creators-where6 ECCEZIONE: #{e.message}")
  #       raise e
  #     end
  #     reply creators
  #   end
  # end

  # namespace "/creators-where7" do
  #   get do
  #     creators = ""
  #     begin
  #       creators = Creator.where(:givenName=>"pippo", :creatorIdentifiers=>[{:nameIdentifierScheme=>"a", :schemeURI=>"b", :nameIdentifier=>"c"}]).include(Creator.goo_attrs_to_load(includes_param)).all
  #     rescue => e
  #       #LOGGER.debug("\n\n CreatorController /creators-where8 ECCEZIONE: #{e.message}")
  #       raise e
  #     end
  #     reply creators
  #   end
  # end

  # namespace "/creators-where8-One-Condition-and" do
  #   get do
  #     creators = ""
  #     begin
  #       whereStatement = Creator.where(:givenName=>"pippo")
  #               .and(:creatorIdentifiers=>[{:nameIdentifierScheme=>"a", :schemeURI=>"b", :nameIdentifier=>"c"}])

  #       #LOGGER.debug("\n\n CreatorController /creators-where8 whereStatement: #{whereStatement.inspect}}")
  #       creators = whereStatement.include(Creator.goo_attrs_to_load(includes_param)).all
  #     rescue => e
  #       #LOGGER.debug("\n\n CreatorController /creators-where8 ECCEZIONE: #{e.message}")
  #       raise e
  #     end
  #     reply creators
  #   end
  # end

  # namespace "/creators-where9-Two-Condition-and" do
  #   get do
  #     creators = ""
  #     begin
  #       whereStatement = Creator.where(:givenName=>"pippo")
  #       .and(:creatorIdentifiers=>[{:nameIdentifierScheme=>"a", :schemeURI=>"b", :nameIdentifier=>"c"}])
  #       .and(:creatorIdentifiers=>[{:nameIdentifierScheme=>"aa", :schemeURI=>"bb", :nameIdentifier=>"cc"}])
  #       #LOGGER.debug("\n\n CreatorController /creators-where9 whereStatement: #{whereStatement.inspect}}")
  #       creators = whereStatement.include(Creator.goo_attrs_to_load(includes_param)).all
  #     rescue => e
  #       #LOGGER.debug("\n\n CreatorController /creators-where9 ECCEZIONE: #{e.message}")
  #       raise e
  #     end
  #     reply creators
  #   end
  # end

  # namespace "/creators-test1" do
  #   get do
  #     creators = nil
  #     begin
  #       creators = Creator.where(givenName:"pippo")
  #               .and(creatorIdentifiers: [nameIdentifierScheme: "a"]).include(Creator.goo_attrs_to_load(includes_param)).all
  #     rescue => e
  #       #LOGGER.debug("\n\n CreatorController /creators-test1 ECCEZIONE: #{e.message}")
  #       raise e
  #     end
  #     reply creators
  #   end   
  # end

  # namespace "/creators-test2" do
  #   get do
  #     creators = nil
  #     begin
  #       creators = Creator.where(givenName:"pippo")
  #               .and(creatorIdentifiers: [nameIdentifierScheme: "a", schemaURI: "b", nameIdentifier: "c"]).include(Creator.goo_attrs_to_load(includes_param)).all
  #     rescue => e
  #       #LOGGER.debug("\n\n CreatorController /creators-test1 ECCEZIONE: #{e.message}")
  #       raise e
  #     end
  #     reply creators
  #   end   
  # end


  # namespace "/creators-test3" do
  #   get do
  #     creators = nil
  #     begin
  #       a_creatorObj = LinkedData::Models::Creator.new(givenName: "pippo", familyName: "bianchi")
  #       query = Creator.where.models([a_creatorObj]).include(Creator.goo_attrs_to_load(includes_param))
        
  #       creators = query.all
  #     rescue => e
  #       #LOGGER.debug("\n\n CreatorController /creators-test3 ECCEZIONE: #{e.message}")
  #       raise e
  #     end
  #     reply creators
  #   end   
  # end

  # namespace "/creators-test4" do
  #   get do
  #     creators = nil
  #     begin
  #       #creator_model={:givenName=>"pippo", :creatorIdentifiers=>[{:nameIdentifierScheme=>"aa", :schemeURI=>"bb", :nameIdentifier=>"cc"}]}
  #       creatorIdentifier = LinkedData::Models::CreatorIdentifier.new(nameIdentifierScheme: "a", schemeURI: "b", nameIdentifier: "c")
  #       a_creatorObj = LinkedData::Models::Creator.new(givenName: "pippo", familyName: "bianchi", creatorIdentifiers:[creatorIdentifier])
        
  #       query = Creator.where.models([a_creatorObj]).include(Creator.goo_attrs_to_load(includes_param))

  #       creators = query.all
  #     rescue => e
  #       #LOGGER.debug("\n\n CreatorController /creators-test4 ECCEZIONE: #{e.message}")
  #       raise e
  #     end
  #     reply creators
  #   end   
  # end

  

  # namespace "/creators-add" do
  #   get do
  #     begin
  #       creatorIdentifier = LinkedData::Models::CreatorIdentifier.new(nameIdentifierScheme: "d", schemeURI: "e", nameIdentifier: "f")
  #       creatorIdentifier2 = LinkedData::Models::CreatorIdentifier.new(nameIdentifierScheme: "dd", schemeURI: "ee", nameIdentifier: "ff")
        
  #       title = LinkedData::Models::Title.new(title: "My Title", lang: "en-EN", titleType: "Other")

  #       creatorObj = LinkedData::Models::Creator.new(nameType: "Personal", givenName: "pippo", familyName: "neri", creatorName: "pippo neri")
  #       # array = [creatorIdentifier, creatorIdentifier2]
  #       # c.creatorIdentifiers = array
  #       #LOGGER.debug("\n\n CreatorController /creators-add BEFORE SAVING 1 creatorObj: #{creatorObj.inspect}")

  #       creatorObj = LinkedData::Models::Creator.new(nameType: "Personal", givenName: "pippo", familyName: "neri", creatorName: "pippo neri", creatorIdentifiers: [creatorIdentifier, creatorIdentifier2], titles:[title])
  #       #LOGGER.debug("\n\n CreatorController /creators-add BEFORE SAVING 2 creatorObj: #{creatorObj.inspect}")

  #       savedObj = creatorObj.save();
  #       replay savedObj
  #     rescue => e
  #       #LOGGER.debug("\n\n CreatorController /creators-add ECCEZIONE: #{e.message}")
  #       raise e
  #     end
  #   end
  # end

  # namespace "/creators-delete" do
  #   get "/:id" do
  #     identifiers = ""
  #       begin
  #         creator = Creator.find(params[:id]).include(Creator.goo_attrs_to_load(includes_param)).first          
  #         if creator.nil?
  #           reply "creator non trovato"
  #         else
  #           errors = creator.delete
  #           if errors.nil
  #             reply "NESSUN ERRORE"
  #           else
  #             reply "ERRORE: #{errors.inspect}"
  #           end
  #         end

  #       rescue => e
  #         #LOGGER.debug("\n\n ###### CreatorIdentifierController /creator_identifier ECCEZIONE: #{e.message}")
  #         raise e
  #       end
  #       reply identifiers
  #   end
  # end

end
