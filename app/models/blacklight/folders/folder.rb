module Blacklight::Folders
  class Folder < ActiveRecord::Base
    belongs_to :user, polymorphic: true
    validates :user, presence: true
    validates :name, presence: true

    after_initialize :default_values

    has_many :items, -> { order('position ASC') }, class_name: 'FolderItem', :dependent => :destroy
    has_many :bookmarks, -> { order('blacklight_folders_folder_items.position ASC') }, through: :items
    accepts_nested_attributes_for :items, allow_destroy: true

    # visibility
    PUBLIC = 'public'
    PRIVATE = 'private'
    before_save :apply_visibility

    # How many folders will appear in the drop-down menu
    MENU_LIMIT = 5

    def default_values
      self.number_of_members ||= 0
      self.visibility ||= Blacklight::Folders::Folder::PRIVATE
    end

    def recalculate_size
      self.number_of_members = items.count
    end

    def documents
      doc_ids = bookmarks.pluck(:document_id)
      return [] if doc_ids.empty?

      rows = doc_ids.count
      query_ids = doc_ids.map{|id| RSolr.escape(id) }
      query_ids = query_ids.join(' OR ')

      response = Blacklight.solr.select(params: { q: "id:(#{query_ids})", qt: 'document', rows: rows})['response']['docs']

      # Put them into the right order (same order as doc_ids),
      # and cast them to the right model.
      model_names = bookmarks.pluck(:document_type)
      docs = doc_ids.map.with_index {|id, i|
        doc_hash = response.find{|doc| doc['id'] == id }
        solr_document_model = model_names[i].safe_constantize
        raise "Couldn't find Solr document for id: `#{id}'" unless doc_hash
        solr_document_model.new(doc_hash)
      }
    end

    def default_visibility
      PRIVATE
    end

    def apply_visibility
      self.visibility ||= default_visibility
    end

    def blacklight_config
      ::CatalogController.blacklight_config
    end

    def add_bookmarks(doc_ids=[])
      doc_ids.each do |doc_id|
        b = bookmarks.build(document_id: doc_id, user_id: user_id)
        b.document_type = blacklight_config.solr_document_model.to_s
      end
    end

    def remove_bookmarks(items=[])
      self.items.delete(items)
    end

    class << self
      # Find the folders that belong to this user and don't contain this document
      def without_doc_for_user(document, user)
        if user.new_record?
          user.folders
        else
          subquery = Blacklight::Folders::FolderItem.select(:folder_id).joins(:bookmark).where('bookmarks.document_id' => document.id).to_sql

          where(user: user).where("id not in (#{subquery})")
        end
      end

      def most_recent
        order('updated_at DESC')
      end

      def default_folder_name
        I18n.translate(:'blacklight.folders.default_folder_name')
      end
    end
  end
end
