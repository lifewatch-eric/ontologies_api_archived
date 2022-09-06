class ContactController < ApplicationController

  namespace "/contacts" do

    ##
    # Display all ontologies
    get do
      contacts = ""
      begin
        contacts = Contact.where.include(Contact.goo_attrs_to_load(includes_param)).all
      rescue => e
        #LOGGER.debug("\n\n ContactController /contacts ECCEZIONE: #{e.message}")
        raise e
      end
      reply contacts
    end
  end

  
  # namespace "/contacts-where1" do
  #   get do
  #     contacts = ""
  #     begin
  #       match={:name=>"claudio"}
  #       contacts = Contact.where(match).include(Contact.goo_attrs_to_load(includes_param)).all
  #     rescue => e
  #       #LOGGER.debug("\n\n ContactController /contacts-where1 ECCEZIONE: #{e.message}")
  #       raise e
  #     end
  #     reply contacts
  #   end
  # end

  # namespace "/contacts-where2" do
  #   get do
  #     contacts = ""
  #     begin
  #       match={:name=>"claudio cruschi"}
  #       contacts = Contact.where(match).include(Contact.goo_attrs_to_load(includes_param)).all
  #     rescue => e
  #       #LOGGER.debug("\n\n ContactController /contacts-where2 ECCEZIONE: #{e.message}")
  #       raise e
  #     end
  #     reply contacts
  #   end
  # end

  # namespace "/contacts-where3" do
  #   get do
  #     contacts = ""
  #     begin
  #       match={:name=>"claudio cruschi", :email=>"c.cruschi@elif.it"}
  #       contacts = Contact.where(match).include(Contact.goo_attrs_to_load(includes_param)).all
  #     rescue => e
  #       #LOGGER.debug("\n\n ContactController /contacts-where3 ECCEZIONE: #{e.message}")
  #       raise e
  #     end
  #     reply contacts
  #   end
  # end

end
