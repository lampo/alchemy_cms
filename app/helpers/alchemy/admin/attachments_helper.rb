module Alchemy::Admin::AttachmentsHelper

  def mime_to_human mime
    I18n.t("alchemy.mime_types.#{mime}", :default => _('document'))
  end

end