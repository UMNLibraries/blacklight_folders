module Blacklight::Folders
  class Folder < ActiveRecord::Base
    belongs_to :user, polymorphic: true
    validates :user_id, presence: true
    validates :name, presence: true

    has_many :items, -> { order('position ASC') }, class_name: 'FolderItem', :dependent => :destroy

    # visibility
    PUBLIC = 'public'
    PRIVATE = 'private'

    # Find the folders that belong to this user and don't contain this document
    def self.without_doc_for_user(document, user)
      selection = "SELECT blacklight_folders_folders.id AS id, blacklight_folders_folders.name AS name from blacklight_folders_folders"
      query_to_match_doc_id = "(SELECT * from blacklight_folders_folder_items WHERE blacklight_folders_folder_items.document_id = '#{document.id}')"
      query = "#{selection} LEFT OUTER JOIN #{query_to_match_doc_id} AS MATCHES_DOC_ID ON blacklight_folders_folders.id = MATCHES_DOC_ID.folder_id WHERE MATCHES_DOC_ID.document_id IS NULL AND blacklight_folders_folders.user_id = #{user.id}"
      find_by_sql(query)
    end

  end
end
