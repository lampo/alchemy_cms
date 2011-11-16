module Alchemy::BaseHelper

  include FastGettext::Translation

  # An alias for truncate.
  # Left here for downwards compatibilty.
  def shorten(text, length)
    text.truncate(:length => length)
  end

  # This helper renders the link for an overlay window.
  # We use this for our fancy modal overlay windows in the Alchemy cockpit.
  def link_to_overlay_window(content, url, options={}, html_options={})
    default_options = {
      :size => "100x100",
      :resizable => false,
      :modal => true,
      :overflow => false
    }
    options = default_options.merge(options)
    link_to_function(
      content,
      "Alchemy.openWindow(
        \'#{url}\',
        \'#{options[:title]}\',
        \'#{options[:size].split('x')[0].to_s}\',
        \'#{options[:size].split('x')[1].to_s}\',
        #{options[:resizable]},
        #{options[:modal]},
        #{options[:overflow]}
      )",
      html_options
    )
  end

  # Used for rendering the folder link in Admin::Pages.index sitemap.
  def sitemapFolderLink(page)
    return '' if page.level == 1
    if page.folded?(current_user.id)
      css_class = 'folded'
      title = _('Show childpages')
    else
      css_class = 'collapsed'
      title = _('Hide childpages')
    end
    link_to(
      '',
      fold_admin_page_path(page),
      :remote => true,
      :method => :post,
      :class => "page_folder #{css_class}",
      :title => title,
      :id => "fold_button_#{page.id}"
    )
  end

  # Returns @current_language set in the action (e.g. Page.show)
  def current_language
    if @current_language.nil?
      warning('@current_language is not set')
      return nil
    else
      @current_language
    end
  end

  # Used for language selector in Alchemy cockpit sitemap. So the user can select the language branche of the page.
  def language_codes_for_select
    configuration(:languages).collect{ |language|
      language[:language_code]
    }
  end

  # Used for translations selector in Alchemy cockpit user settings.
  def translations_for_select
    configuration(:translations).collect{ |translation|
      [translation[:language], translation[:language_code]]
    }
  end

  # Used by Alchemy to display a javascript driven filter for lists in the Alchemy cockpit.
  def js_filter_field options = {}
    default_options = {
      :class => "thin_border js_filter_field",
      :onkeyup => "Alchemy.ListFilter('#contact_list li')",
      :id => "search_field"
    }
    options = default_options.merge(options)
    options[:onkeyup] << ";jQuery('#search_field').val().length >= 1 ? jQuery('.js_filter_field_clear').show() : jQuery('.js_filter_field_clear').hide();"
    filter_field = "<div class=\"js_filter_field_box\">"
    filter_field << text_field_tag("filter", '', options)
    filter_field << content_tag('span', '', :class => 'icon search')
    filter_field << link_to_function(
      "",
      "jQuery('##{options[:id]}').val('');#{options[:onkeyup]}",
      :class => "js_filter_field_clear",
      :style => "display:none",
      :title => _("click_to_show_all")
    )
    filter_field << "<label for=\"search_field\">" + _("search") + "</label>"
    filter_field << "</div>"
    filter_field.html_safe
  end
  
  def link_to_confirmation_window(link_string = "", message = "", url = "", html_options = {})
    title = _("please_confirm")
    ok_lable = _("yes")
    cancel_lable = _("no")
    link_to_function(
      link_string,
      "Alchemy.confirmToDeleteWindow('#{url}', '#{title}', '#{message}', '#{ok_lable}', '#{cancel_lable}');",
      html_options
    )
  end

  # Renders a form select tag for storing page urlnames
  # Options:
  #   * element - element the Content find via content_name to store the pages urlname in.
  #   * content_name - the name of the content from element to store the pages urlname in.
  #   * options (Hash)
  #   ** :only (Hash)  - pass page_layout names to :page_layout => [""] so only pages with this page_layout will be displayed inside the select.
  #   ** :except (Hash)  - pass page_layout names to :page_layout => [""] so all pages except these with this page_layout will be displayed inside the select.
  #   ** :page_attribute (Symbol) - The Page attribute which will be stored.
  #   * select_options (Hash) - will be passed to the select_tag helper
  def page_selector(element, content_name, options = {}, select_options = {})
    default_options = {
      :except => {
        :page_layout => [""]
      },
      :only => {
        :page_layout => [""]
      },
      :page_attribute => :urlname,
      :prompt => _('Choose page')
    }
    options = default_options.merge(options)
    content = element.content_by_name(content_name)
    if content.nil?
      return warning('Content', _('content_not_found'))
    elsif content.essence.nil?
      return warning('Content', _('content_essence_not_found'))
    end
    pages = Page.where({
      :language_id => session[:language_id],
      :page_layout => options[:only][:page_layout],
      :public => true
    })
    select_tag(
      "contents[content_#{content.id}][body]",
      pages_for_select(pages, content.essence.body, options[:prompt], options[:page_attribute]),
      select_options
    )
  end
  
  # Returns an Array build for passing it to the options_for_select helper inside an essence editor partial.
  # Usefull for the select_values options from the render_essence_editor helpers.
  # Options:
  #   * :from_page (String, Page) - Return only elements from this page. You can either pass a Page instance, or a page_layout name
  #   * :elements_with_name (Array, String) - Return only elements with this name(s).
  def elements_for_essence_editor_select(options={})
    defaults = {
      :from_page => nil,
      :elements_with_name => nil,
      :prompt => _('Please choose')
    }
    options = defaults.merge(options)
    if options[:from_page]
      page = options[:from_page].is_a?(String) ? Page.find_by_page_layout(options[:from_page]) : options[:from_page]
    end
    if page
      elements = options[:elements_with_name].blank? ? page.elements.find_all_by_public(true) : page.elements.find_all_by_public_and_name(true, options[:elements_with_name])
    else
      elements = options[:elements_with_name].blank? ? Element.find_all_by_public(true) : Element.find_all_by_public_and_name(true, options[:elements_with_name])
    end
    select_options = [[options[:prompt], ""]]
    elements.each do |e|
      select_options << [e.display_name_with_preview_text, e.id.to_s]
    end
    select_options
  end
  
  # Returns all Pages found in the database as an array for the rails select_tag helper.
  # You can pass a collection of pages to only returns these pages as array.
  # Pass an Page.name or Page.id as second parameter to pass as selected for the options_for_select helper.
  def pages_for_select(pages = nil, selected = nil, prompt = "", page_attribute = :id)
    result = [[prompt.blank? ? _('Choose page') : prompt, ""]]
    if pages.blank?
      pages = Page.find_all_by_language_id_and_public(session[:language_id], true)
    end
    pages.each do |p|
      result << [p.name, p.send(page_attribute).to_s]
    end
    options_for_select(result, selected.to_s)
  end

  def render_essence_selection_editor(element, content, select_options)
    if content.class == String
       content = element.contents.find_by_name(content)
    else
      content = element.contents[content - 1]
    end
    if content.essence.nil?
      return warning('Element', _('content_essence_not_found'))
    end
    select_options = options_for_select(select_options, content.essence.content)
    select_tag(
      "contents[content_#{content.id}]",
      select_options
    )
  end

  # TOOD: include these via asset_packer yml file
  def stylesheets_from_plugins
    Dir.glob("vendor/plugins/*/assets/stylesheets/*.css").inject("") do |acc, s|
      filename = File.basename(s)
      plugin = s.split("/")[2]
      acc << stylesheet_link_tag("#{plugin}/#{filename}")
    end
  end

  # TOOD: include these via asset_packer yml file
  def javascripts_from_plugins
    Dir.glob("vendor/plugins/*/assets/javascripts/*.js").inject("") do |acc, s|
      filename = File.basename(s)
      plugin = s.split("/")[2]
      acc << javascript_include_tag("#{plugin}/#{filename}")
    end
  end

  def admin_main_navigation
    navigation_entries = alchemy_plugins.collect{ |p| p["navigation"] }
    render :partial => 'alchemy/admin/partials/mainnavigation_entry', :collection => navigation_entries.flatten
  end

  # Renders the Subnavigation for the admin interface.
  def render_admin_subnavigation(entries)
    render :partial => "alchemy/admin/partials/sub_navigation", :locals => {:entries => entries}
  end

  def admin_subnavigation
    plugin = alchemy_plugin(:controller => params[:controller], :action => params[:action])
    unless plugin.nil?
      entries = plugin["navigation"]['sub_navigation']
      render_admin_subnavigation(entries) unless entries.nil?
    else
      ""
    end
  end

  def admin_mainnavi_active?(mainnav)
    subnavi = mainnav["sub_navigation"]
    nested = mainnav["nested"]
    if !subnavi.blank?
      (!subnavi.detect{ |subnav| subnav["controller"] == params[:controller] && subnav["action"] == params[:action] }.blank?) ||
      (!nested.nil? && !nested.detect{ |n| n["controller"] == params[:controller] && n["action"] == params[:action] }.blank?)
    else
      mainnav["controller"] == params[:controller] && mainnav["action"] == params["action"]
    end
  end

	# Helper for including all nescessary javascripts and stylesheets.
	# Under Rails 3.1 it uses the asset pipeline.
	# Under Rails 3.0.x we use caching to combine the files into one big asset file.
	def alchemy_combined_assets
		asset_sets = YAML.load_file(File.join(File.dirname(__FILE__), '..', '..', 'config/asset_packages.yml'))
		if Rails.version >= '3.1'
			content_for(:javascript_includes) do
				javascript_include_tag('alchemy/alchemy')
			end
			content_for(:stylesheets) do
				stylesheet_link_tag('alchemy/alchemy', :media => 'screen')
			end
			content_for(:stylesheets) do
				stylesheet_link_tag('alchemy/print', :media => 'print')
			end
		else
			content_for(:javascript_includes) do 
				js_set = asset_sets['javascripts'].detect { |js| js[setname.to_s] }[setname.to_s]
				javascript_include_tag(js_set, :cache => 'alchemy/' + setname.to_s)
			end
			css_set = asset_sets['stylesheets'].detect { |css| css[setname.to_s] }[setname.to_s]
			content_for(:stylesheets) do
				stylesheet_link_tag(css_set, :cache => 'alchemy/' + setname.to_s, :media => 'screen')
			end
			content_for(:stylesheets) do
				print_set = css_set.clone << 'alchemy/print'
				stylesheet_link_tag(print_set, :cache => 'alchemy/' + setname.to_s + '-print', :media => 'print')
			end
		end
	end
	alias_method :alchemy_assets_set, :alchemy_combined_assets

  def parse_sitemap_name(page)
    if multi_language?
      pathname = "/#{session[:language_code]}/#{page.urlname}"
    else
      pathname = "/#{page.urlname}"
    end
    pathname
  end

  # Returns an icon
  def render_icon(icon_class)
    content_tag('span', '', :class => "icon #{icon_class}")
  end

  # Logs a message in the Rails logger (warn level) and optionally displays an error message to the user.
  def warning(message, text = nil)
    logger.warn %(\n
      ++++ WARNING: #{message}! from: #{caller.first}\n
    )
    unless text.nil?
      warning = content_tag('p', :class => 'content_editor_error') do
        render_icon('warning') + text
      end
      return warning
    end
  end

  def necessary_options_for_cropping_provided?(options)
    options[:crop].to_s == 'true' && !options[:image_size].blank?
  end

  # Renders translated Module Names for html title element.
  def render_alchemy_title
    key = 'module: ' + controller_name
    if content_for?(:title)
      title = content_for(:title)
    elsif FastGettext.key_exist?(key)
      title = _(key)
    else
      title = controller_name.humanize
    end
    "Alchemy CMS - #{title}"
  end

  # Returns max image count as integer or nil. Used for the picture editor in element editor views.
  def max_image_count
    return nil if !@options
    if @options[:maximum_amount_of_images].blank?
      image_count = @options[:max_images]
    else
      image_count = @options[:maximum_amount_of_images]
    end
    if image_count.blank?
      nil
    else
      image_count.to_i
    end
  end

	def clipboard_select_tag(items, html_options = {})
    options = [[_('Please choose'), ""]]
    items.each do |item|
      options << [item.class.to_s == 'Element' ? item.display_name_with_preview_text : item.name, item.id]
    end
    select_tag(
      'paste_from_clipboard',
      !@page.new_record? && @page.can_have_cells? ? grouped_elements_for_select(items, :id) : options_for_select(options),
      {
        :class => html_options[:class] || 'very_long',
        :style => html_options[:style]
      }
    )
  end

	# Taken from tinymce_hammer plugin
	def append_class_name options, class_name #:nodoc:
		key = options.has_key?('class') ? 'class' : :class 
		unless options[key].to_s =~ /(^|\s+)#{class_name}(\s+|$)/
			options[key] = "#{options[key]} #{class_name}".strip
		end
		options
	end

end