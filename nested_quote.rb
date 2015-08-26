# -*- coding: utf-8 -*-

class Gdk::NestedQuote < Gdk::SubParts
  regist

  TWEET_URL = [ %r[\Ahttps?://twitter.com/(?:#!/)?(?<screen_name>[a-zA-Z0-9_]+)/status(?:es)?/(?<id>\d+)(?:\?.*)?\Z],
                %r[\Ahttp://favstar\.fm/users/(?<screen_name>[a-zA-Z0-9_]+)/status/(?<id>\d+)],
                %r[\Ahttp://aclog\.koba789\.com/i/(?<id>\d+)]].freeze

  attr_reader :icon_width, :icon_height

  def initialize(*args)
    super
    @icon_width, @icon_height, @margin, @edge = 32, 32, 2, 8
    if has_tweet_url?
      Thread.new(get_tweet_ids) { |tweet_ids|
        messages = []
        tweet_ids.each_with_index.map { |message_id, index|
          Thread.new {
            messages[index] = Message.findbyid(message_id.to_i) } }.each(&:join)
        @messages = messages.select { |m| m.is_a? Message }
        Delayer.new {
          render_messages } } end end

  def render_messages
    if not helper.destroyed?
      helper.on_modify
      helper.reset_height
      helper.ssc(:click) { |this, e, x, y|
        ofsty = helper.mainpart_height
        helper.subparts.each { |part|
          break if part == self
          ofsty += part.height }
        if ofsty <= y and (ofsty + height) >= y
          case e.button
          when 1
            my = 0
            @messages.each { |m|
              my += message_height(m)
              if y <= ofsty + my
                Plugin.filtering(:command, {}).first[:smartthread][:exec].call(Struct.new(:messages).new([m]))
                break end } end end } end end

  def render(context)
    if @messages and not @messages.empty?
      @messages.inject(0) { |base_y, message|
        render_single_message(message, context, base_y) } end end

  def height
    if not helper.destroyed? and @messages and not @messages.empty?
      @messages.inject(0) { |s, m| s + message_height(m) }
    else
      0 end end

  private

  def id2url(url)
    TWEET_URL.each{ |regexp|
      m = regexp.match(url)
      return m[:id] if m }
    false end

  # ツイートへのリンクを含んでいれば真
  def has_tweet_url?
    helper.message.entity.any?{ |entity|
      :urls == entity[:slug] and id2url(entity[:expanded_url]) } end

  # ツイートの本文に含まれるツイートのパーマリンクを返す
  # ==== Return
  # URLの配列
  def get_tweet_ids
    helper.message.entity.map{ |entity|
      if :urls == entity[:slug]
        id2url(entity[:expanded_url]) end }.select(&ret_nth) end

  def render_single_message(message, context, base_y)
    render_outline(message, context, base_y)
    render_header(message, context, base_y)
    context.save {
      context.translate(@margin + @edge, @margin + @edge + base_y)
      context.set_source_pixbuf(main_icon(message))
      context.paint
      context.translate(icon_width + @margin*2, header_left(message).size[1] / Pango::SCALE)
      context.set_source_rgb(*([0,0,0]).map{ |c| c.to_f / 65536 })
      context.show_pango_layout(main_message(message, context)) }

    base_y + message_height(message) end

  def message_height(message)
    [icon_height, (header_left(message).size[1] + main_message(message).size[1]) / Pango::SCALE].max + (@margin + @edge) * 2
  end

  # ヘッダ（左）のための Pango::Layout のインスタンスを返す
  def header_left(message, context = dummy_context)
    attr_list, text = Pango.parse_markup("<b>#{Pango.escape(message[:user][:idname])}</b> #{Pango.escape(message[:user][:name] || '')}")
    layout = context.create_pango_layout
    layout.attributes = attr_list
    layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_basic_font])
    layout.text = text
    layout end

  # ヘッダ（右）のための Pango::Layout のインスタンスを返す
  def header_right(message, context = dummy_context)
    now = Time.now
    hms = if message[:created].year == now.year && message[:created].month == now.month && message[:created].day == now.day
            message[:created].strftime('%H:%M:%S'.freeze)
          else
            message[:created].strftime('%Y/%m/%d %H:%M:%S'.freeze)
          end
    attr_list, text = Pango.parse_markup("<span foreground=\"#999999\">#{Pango.escape(hms)}</span>")
    layout = context.create_pango_layout
    layout.attributes = attr_list
    layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_basic_font])
    layout.text = text
    layout.alignment = Pango::ALIGN_RIGHT
    layout end

  def render_header(message, context, base_y)
    header_w = width - @icon_width - @margin*3 - @edge*2
    context.save{
      context.translate(@icon_width + @margin*2 + @edge, @margin + @edge + base_y)
      context.set_source_rgb(0,0,0)
      hl_layout, hr_layout = header_left(message, context), header_right(message, context)
      context.show_pango_layout(hl_layout)
      context.save{
        context.translate(header_w - hr_layout.size[0] / Pango::SCALE, 0)
        if (hl_layout.size[0] / Pango::SCALE) > header_w - hr_layout.size[0] / Pango::SCALE - 20
          r, g, b = get_backgroundcolor
          grad = Cairo::LinearPattern.new(-20, base_y, hr_layout.size[0] / Pango::SCALE + 20, base_y)
          grad.add_color_stop_rgba(0.0, r, g, b, 0.0)
          grad.add_color_stop_rgba(20.0 / (hr_layout.size[0] / Pango::SCALE + 20), r, g, b, 1.0)
          grad.add_color_stop_rgba(1.0, r, g, b, 1.0)
          context.rectangle(-20, base_y, hr_layout.size[0] / Pango::SCALE + 20, hr_layout.size[1] / Pango::SCALE + base_y)
          context.set_source(grad)
          context.fill() end
        context.show_pango_layout(hr_layout) } }
  end

  def main_message(message, context = dummy_context)
    attr_list, text = Pango.parse_markup(Pango.escape(message.to_show))
    layout = context.create_pango_layout
    layout.width = (width - @icon_width - @margin*3 - @edge*2) * Pango::SCALE
    layout.attributes = attr_list
    layout.wrap = Pango::WRAP_CHAR
    layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_reply_font])
    layout.text = text
    layout end

  def render_outline(message, context, base_y)
    mh = message_height(message)
    context.save {
      context.pseudo_blur(4) {
        context.fill {
          context.set_source_rgb(*([32767, 32767, 32767]).map{ |c| c.to_f / 65536 })
          context.rounded_rectangle(@edge, @edge + base_y, width - @edge*2, mh - @edge*2, 4)
        }
      }
      context.fill {
        context.set_source_rgb(*([65535, 65535, 65535]).map{ |c| c.to_f / 65536 })
        context.rounded_rectangle(@edge, @edge + base_y, width - @edge*2, mh - @edge*2, 4)
      }
    }
  end

  def main_icon(message)
    Gdk::WebImageLoader.pixbuf(message[:user][:profile_image_url], icon_width, icon_height){ |pixbuf|
      helper.on_modify } end

  def get_backgroundcolor
    [1.0, 1.0, 1.0]
  end
end

Plugin.create :nested_quote do
  # このプラグインが提供するデータソースを返す
  # ==== Return
  # Hash データソース
  def datasources
    ds = {nested_quoted_myself: "ナウい引用(全てのアカウント)".freeze}
    Service.each do |service|
      ds["nested_quote_quotedby_#{service.user_obj.id}".to_sym] = "@#{service.user_obj.idname}/ナウい引用" end
    ds end

  command(:copy_tweet_url,
          name: 'ツイートのURLをコピー',
          condition: Proc.new{ |opt|
            not opt.messages.any?(&:system?)},
          visible: true,
          role: :timeline) do |opt|
    Gtk::Clipboard.copy(opt.messages.map(&:parma_link).join("\n".freeze))
  end

  filter_extract_datasources do |ds|
    [ds.merge(datasources)] end

  # 管理しているデータソースに値を注入する
  on_appear do |ms|
    ms.each do |message|
      quoted_screen_names = message.entity.select{ |entity| :urls == entity[:slug] }.map{ |entity|
        Gdk::NestedQuote::TWEET_URL.find { |matcher| matcher =~ entity[:expanded_url] }
        $~[:screen_name] if $~ && $~.names.include?("screen_name") }.uniq
      quoted_services = Service.select{|service| quoted_screen_names.include? service.user_obj.idname }
      unless quoted_services.empty?
        quoted_services.each do |service|
          Plugin.call :extract_receive_message, "nested_quote_quotedby_#{service.user_obj.id}".to_sym, [message] end
        Plugin.call :extract_receive_message, :nested_quoted_myself, [message] end end end
end
