class WikiPageController < BasePageController
  include ControllerExtension::WikiRenderer
  include ControllerExtension::WikiImagePopup

  stylesheet 'wiki_edit'
  javascript 'wiki_edit'
  helper :wiki # for wiki toolbar stuff

  ##
  ## ACCESS: no restriction
  ##

  def create
    @page_class = WikiPage
    if params[:cancel]
      return redirect_to(create_page_url(nil, :group => params[:group]))
    elsif request.post?
      begin
        @page = create_new_page!(@page_class)
        if params[:asset] and params[:asset][:uploaded_data].any?
          @asset = Asset.make!(params[:asset].merge(:parent_page => @page))
          image_tag = "!<%s!:%s" % [@asset.thumbnail(:medium).url,@asset.url]
        end
        body = "%s\n\n%s" % [image_tag, params[:body]]
        @page.update_attribute(:data, Wiki.create(:user => current_user, :body => body))
        if body.strip.empty?
          return redirect_to(page_url(@page, :action => 'edit'))
        else
          return redirect_to(page_url(@page, :action => 'show'))
        end
      rescue Exception => exc
        @page = exc.record
        flash_message_now :exception => exc
      end
    else
      @page = build_new_page(@page_class)
    end
  end

  ##
  ## ACCESS: public or :view
  ##

  def show
    if @wiki.body.empty?
      redirect_to page_url(@page,:action=>'edit')
      return
    elsif @upart and !@upart.viewed? and @wiki.version > 1
      @last_seen = @wiki.first_since( @upart.viewed_at )
    end
    # render if needed
    @wiki.render_html{|body| render_wiki_html(body, @page.owner_name)}

    if logged_in? and heading = @wiki.currently_editing_section(current_user)
      # if the user has a particular section locked, then show it to them.
      if heading == :all
        redirect_to page_url(@page,:action=>'edit')
      else
        @wiki.body_html = body_html_with_form(heading)
      end
    end
  end

  def version
    @version = @wiki.versions.find_by_version(params[:id])
  end

  def versions
  end

  def diff
    old_id, new_id = params[:id].split('-')
    @old = @wiki.versions.find_by_version(old_id)
    @old.render_html{|body| render_wiki_html(body, @page.owner_name)} # render if needed

    @new = @wiki.versions.find_by_version(new_id)
    @new.render_html{|body| render_wiki_html(body, @page.owner_name)} # render if needed

    @old_markup = @old.body_html || ''
    @new_markup = @new.body_html || ''
    @difftext = HTMLDiff.diff( @old_markup , @new_markup)

    # output diff html only for ajax requests
    render :text => @difftext if request.xhr?
  end

  def print
    # render if needed
    @wiki.render_html{|body| render_wiki_html(body, @page.owner_name)}
    render :layout => "printer-friendly"
  end

  ##
  ## ACCESS: :edit
  ##
  def edit
    if params[:cancel]
      cancel
    elsif params[:break_lock]
      unlock
      lock
      @wiki.body = params[:wiki][:body]
    elsif request.post? and params[:save]
      # update
      save
    elsif request.get?
      lock
    end
  end

  def cancel
    unlock if @wiki.locked_by_id == current_user.id
    redirect_to page_url(@page, :action => 'show')
  end

  # TODO: make post only
  def break_lock
    # will unlock all sections
    unlock
    redirect_to page_url(@page, :action => 'edit')
  end

  ##
  ## INLINE WIKI EDITING
  ##

  def edit_inline
    heading = params[:id]
    @wiki.lock(Time.now, current_user, heading)
    update_inline_html(heading)
  rescue WikiLockException
    @locker = User.find_by_id @wiki.locked_by_id(heading)
    @locker ||= User.new :login => 'unknown'
    @wiki_inline_error = 'This wiki is currently locked by :user'[:wiki_locked] % {:user => @locker.display_name}
    update_inline_html(heading)
  end

  def save_inline
    heading = params[:id]
    @wiki.unlock_everything_by(current_user)

    if params[:save]
      body = params[:body]
      greencloth = GreenCloth.new(@wiki.body)

      greencloth.set_text_for_heading(heading, body)

      @wiki.body = greencloth.to_s
      @wiki.save
    end

    update_inline_html(nil)
  end

  def update_inline_html(heading)
    @wiki.render_html{|body| render_wiki_html(body, @page.owner_name)}
    # render the edit remaining forms
    if heading
      @wiki.body_html = body_html_with_form(heading)
    end
    render :update do |page|
      page.replace_html(:wiki_html, :partial => 'show_rendered_wiki')
    end
  end

  protected

  def save
    begin
      @wiki.smart_save!( params[:wiki].merge(:user => current_user) )
      # unlock if we have the lock
      current_user.updated(@page)
      #@page.save
      redirect_to page_url(@page, :action => 'show')
    rescue ActiveRecord::StaleObjectError
      # this exception is created by optimistic locking.
      # it means that @wiki has change since we fetched it from the database
      flash_message_now :error => "locking error. can't save your data, someone else has saved new changes first."[:locking_error]
    rescue ErrorMessage => exc
      flash_message_now :error => exc.to_s
      @wiki.body = params[:wiki][:body]
    end
  end

  def unlock
    @wiki.unlock
  end

  def lock
    if @wiki.editable_by? current_user
      @wiki.lock(Time.zone.now, current_user)
    end
  end

  # called early in filter chain
  def fetch_data
    return true unless @page

    @wiki = @page.data
  end

  # before filter
  def setup_view
    @show_attach = true
    unless @wiki.nil? or @wiki.editable_by?(current_user)
      @title_addendum = render_to_string(:partial => 'locked_notice')
    end
  end

  def authorized?
    if @page
      if %w(show print diff version versions).include? params[:action]
        @page.public? or current_user.may?(:view, @page)
      elsif %w(edit break_lock upload).include? params[:action]
        current_user.may?(:edit, @page)
      else
        current_user.may?(:admin, @page)
      end
    else
      true
    end
  end

  # returns the body html, but with a form in the place of the named heading
  def body_html_with_form(heading)
    html = @wiki.body_html.dup
    return html if heading.blank?

    greencloth = GreenCloth.new(@wiki.body)
    text_to_edit = greencloth.get_text_for_heading(heading)

    form = render_to_string :partial => 'edit_inline', :locals => {:text => text_to_edit, :heading => heading}
    form << "\n"
    next_heading = greencloth.heading_tree.successor(heading)
    next_heading = next_heading ? next_heading.name : nil
    html = replace_section_with_form(html, heading, next_heading, form)

    @heading_with_form = heading
    html
  end

  # Takes some html and a section (defined from heading_start to heading_end)
  # and replaces the section with the form. This is pretty crude, and might not
  # work in all cases.
  def replace_section_with_form(html, heading_start, heading_end, form)
    index_start = html.index /^<h[1-4](\s+class=["']first["'])?><a name="#{Regexp.escape(heading_start)}">/
    if heading_end
      index_end = html.index /^<h[1-4]><a name="#{Regexp.escape(heading_end)}">/
      index_end -= 1
    else
      index_end = -1
    end
    html[index_start..index_end] = form
    return html
  end

  # which images should be displayed in the image upload popup
  def image_popup_visible_images
    Asset.visible_to(current_user, @page.group).media_type(:image).most_recent.find(:all, :limit=>20)
  end
end
