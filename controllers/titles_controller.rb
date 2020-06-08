class TitlesController < ApplicationController

  namespace "/titles" do

    ##
    # Display all Titles
    get do
      titles = ""
      begin
        check_last_modified_collection(LinkedData::Models::Title)
        titles = Title.where.include(Title.goo_attrs_to_load(includes_param)).all
      rescue => e
        LOGGER.debug("\n\n ###### TitleController /titles ECCEZIONE: #{e.message}\n#{e.backtrace.join("\n")}")
        raise e
      end
      reply titles
    end 
    
    get "/:id" do
      titles = ""
        begin
          titles = Title.find(params[:id]).include(Title.goo_attrs_to_load(includes_param)).all          
        rescue => e
          LOGGER.debug("\n\n ###### TitleController /titles ECCEZIONE: #{e.message}\n#{e.backtrace.join("\n")}")
          raise e
        end
        reply titles
    end
  end 
 

end
