require 'sanitize'
require "sanitize/config/generous"
require "snail_helpers"
require 'color'

module ReaderHelper
  include SnailHelpers
  include Admin::RegionsHelper

  def standard_gravatar_for(reader=nil, url=nil)
    size = Radiant::Config['reader.gravatar_size'] || 40
    url ||= reader_url(reader)
    gravatar = gravatar_for(reader, {:size => size}, {:class => 'gravatar offset', :width => size, :height => size})
    content = (url == :false ? gravatar : link_to(gravatar, url))
    content_tag(:div, content, :class => "speaker", :width => size, :height => size)
  end

  def gravatar_for(reader=nil, gravatar_options={}, img_options ={})
    size = gravatar_options[:size] || 40
    img_options[:size] ||= "#{size}x#{size}"
    gravatar_options[:default] ||= "#{request.protocol}#{request.host_with_port}/images/furniture/no_gravatar.png"
    img_options[:alt] ||= reader.preferred_name if reader
    if reader.nil? || reader.email.blank?
      image_tag gravatar_options[:default], img_options
    else
      image_tag gravatar_url(reader.email, gravatar_options), img_options
    end
  end

  def link_to_reader(reader)
    if page = ReaderPage.first
      page.url_for(reader)
    else
      reader_url(reader)
    end
  end

  def link_to_group(group)
    if page = group.homepage
      link_to group.name, page.url
    else
      link_to group.name, group_url(group)
    end
  end

  def link_to_message(message)
    link_to message.subject, message_url(message)
  end

  def home_page_link(options={})
    home_page = Page.find_by_parent_id(nil)
    link_to home_page.title, home_page.url, options
  end

  def scrub_html(text)
    Sanitize.clean(textilize(text))
  end

  def clean_html(text)
    Sanitize.clean(textilize(text), Sanitize::Config::GENEROUS)
  end

  def truncate_words(text='', options={})
    return '' if text.blank?
    options = {:length => options} unless options.is_a? Hash
    options.reverse_merge!(:length => 30, :omission => '&hellip;')
    words = text.split
    length = options[:length].to_i
    options[:omission] = '' unless words.size > length
    words[0..(length-1)].join(" ") + options[:omission]
  end

  def pagination_and_summary_for(list, name='')
    %{<div class="pagination">
        #{will_paginate list, :container => false}
        <span class="pagination_summary">
          #{pagination_summary(list, name)}
        </span>
      </div>
    }
  end

  def pagination_summary(list, name='')
    total = list.total_entries
    start = list.offset + 1
    finish = ((list.offset + list.per_page) < list.total_entries) ? list.offset + list.per_page : list.total_entries
    t("reader_extension.showing_of_total", :count => total, :start => start, :finish => finish, :name => name, :names => name.pluralize)
  end

  def message_preview(subject, body, reader)
    preview = <<EOM
From: #{current_user.name} &lt;#{current_user.email}&gt;
To: #{reader.preferred_name} &lt;#{reader.email}&gt;
Date: #{Time.now.to_date.to_s :long}
<strong>Subject: #{subject}</strong>

Dear #{reader.preferred_name},

#{body}

EOM
  simple_format(preview)
  end

  def choose_page(object, field, select_options={})
    root = Page.respond_to?(:homepage) ? Page.homepage : Page.find_by_parent_id(nil)
    options = page_option_branch(root)
    options.unshift [t("reader_extension.none_option"), nil]
    select object, field, options, select_options
  end

  def page_option_branch(page, depth=0)
    options = []
    unless page.title.first == '_'
      options << ["#{". " * depth}#{h(page.title)}", page.id]
      page.children.each do |child|
        options += page_option_branch(child, depth + 1)
      end
    end
    options
  end

  def friendly_date(datetime)
    I18n.l(datetime, :format => friendly_date_format(datetime)) if datetime
  end

  def friendly_date_format(datetime)
    if datetime && date = datetime.to_date
      if (date.to_datetime == Date.today)
        :today
      elsif (date.to_datetime == Date.yesterday)
        :yesterday
      elsif (date.to_datetime > 6.days.ago)
        :recently
      elsif (date.year == Date.today.year)
        :this_year
      else
        :standard
      end
    end
  end

  def country_options_for_select(selected = nil, default_selected = Snail.home_country)
    usps_country_options_for_select(selected, default_selected)
  end

  def group_options_for_select
    options_from_tree(Group.arrange).unshift([t("reader_extension.any_option"), nil])
  end

  def parent_group_options_for_select(group=nil)
    options_from_tree(Group.arrange, :except => group).unshift([t("reader_extension.none_option"), nil])
  end

  def email_link(address)
    mail_to address, nil, :encode => :hex, :replace_at => ' at ', :class => 'mailto'
  end

  # Takes a hash of hashes in the format returned by Ancestry#arrange, returns an indented option set.
  #
  def options_from_tree(tree, options={})
    option_list = []
    depth = options[:depth] || 0
    exception = options[:except]
    tree.each_pair do |key, values|
      unless key == exception
        option_list << [". " * depth + key.name, key.id]
        option_list.concat options_from_tree(values, :depth => depth + 1, :except => exception) if values.any?
      end
    end
    option_list.compact
  end

  def pretty_groups(groups)
    groups.map { |group| group_tag(group) }.join("\n")
  end

  def pretty_group_links(groups)
    groups.map do |group|
      link_to(group_tag(group), admin_group_path(group), :class => "group_link")
    end.join("\n")
  end

  def group_tag(group)
    content_tag(:span, group.name, :class => "group_tag #{group.name.parameterize}")
  end

  def css_for_readers_groups readers
    # this should handle either a single reader, or an array being passed in:
    groups = readers.map(&:groups).flatten
    # remove any nils!:
    groups = groups.compact

    css = groups.map { |group|
      group_name = group.name.parameterize #should take care of dumb inputs for us
      hue = ((Math.sin(group.id*431.26570001)+1)/2)*20000 % 360
      colour = Color::HSL.new(hue, 50, 68).html
      hover_colour = Color::HSL.new(hue, 50, 85).html
      ".group_tag.#{group_name} { background-color: #{colour}; } \na:hover .group_tag.#{group_name} { background-color: #{hover_colour}; }"
    }.join("\n")
  end

  def error_messages_except(record, excluded_fields)
    errors = errors_except(record, excluded_fields)
    unless errors.empty?
      error_nodes = errors.map do |key, value|
        content_tag(:li, content_tag(:strong, key.humanize.titleize) + ": #{value}")
      end
      content_tag(:ul, error_nodes.join("\n"), :class => 'error_list')
    end
  end


  def render_group_node(group, locals = {})
    @current_node = group
    locals.reverse_merge!(:level => 0, :simple => false).merge!(:group => group)
    render :partial => 'groups/group_node', :locals =>  locals
  end
  private

  def errors_except(record, excluded_fields)
    results = {}
    record.errors.each do |key, value|
      unless excluded_fields.include?(key.to_sym)
        results[key] = value
      end
    end
    results
  end
end

