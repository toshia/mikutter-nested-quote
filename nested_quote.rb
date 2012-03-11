# -*- coding: utf-8 -*-

class Gdk::NestedQuote < Gdk::SubParts
  regist

  TWEET_URL = /^https?:\/\/twitter.com\/(?:#!\/)?[a-zA-Z0-9_]+\/status(?:es)?\/(\d+)(?:\?.*)?$/
  attr_reader :icon_width, :icon_height

  def initialize(*args)
    super
    @icon_width, @icon_height, @margin, @edge = 32, 32, 2, 8
    @message_got = false
    @messages = []
    if not get_tweet_ids.empty?
      get_tweet_ids.each{ |message_id|
        Thread.new {
          m = Message.findbyid(message_id.to_i)
          if m.is_a? Message
            Delayer.new{
              render_message(m) } end } } end
      if message and not helper.visible?
      sid = helper.ssc(:expose_event, helper){
        helper.on_modify
        helper.signal_handler_disconnect(sid)
        false } end
  end

  def render_message(message)
    notice "found #{message.to_s}"
    if not helper.destroyed?
      @message_got = true
      @messages << message
      helper.on_modify
      helper.reset_height end
  end

  def render(context)
    if helper.visible? and messages
      render_outline(context)
      header(context)
      context.save {
        context.translate(@margin+@edge, @margin+@edge)
        render_main_icon(context)
        context.translate(@icon_width + @margin*2, header_left.size[1]/Pango::SCALE)
        context.set_source_rgb(*([0,0,0]).map{ |c| c.to_f / 65536 })
        context.show_pango_layout(main_message(context)) }
    end
  end

  def height
    if not(helper.destroyed?) and has_tweet_url? and messages and not messages.empty?
      [icon_height, (header_left.size[1]+main_message.size[1])/Pango::SCALE].max + (@margin+@edge)*2
    else
      0 end end

  private

  # ツイートへのリンクを含んでいれば真
  def has_tweet_url?
    message.entity.any?{ |entity|
      :urls == entity[:slug] and TWEET_URL.match(entity[:expanded_url]) } end

  # ツイートの本文に含まれるツイートのパーマリンクを返す
  # ==== Return
  # URLの配列
  def get_tweet_ids
    message.entity.map{ |entity|
      if :urls == entity[:slug]
        matched = TWEET_URL.match(entity[:expanded_url])
        if matched
          matched[1] end end }.select(&ret_nth) end

  def messages
    @messages if @message_got end

  # ヘッダ（左）のための Pango::Layout のインスタンスを返す
  def header_left(context = dummy_context)
    message = messages.first
    attr_list, text = Pango.parse_markup("<b>#{Pango.escape(message[:user][:idname])}</b> #{Pango.escape(message[:user][:name] || '')}")
    layout = context.create_pango_layout
    layout.attributes = attr_list
    layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_basic_font])
    layout.text = text
    layout end

  # ヘッダ（右）のための Pango::Layout のインスタンスを返す
  def header_right(context = dummy_context)
    message = messages.first
    now = Time.now
    hms = if message[:created].year == now.year && message[:created].month == now.month && message[:created].day == now.day
            message[:created].strftime('%H:%M:%S')
          else
            message[:created].strftime('%Y/%m/%d %H:%M:%S')
          end
    attr_list, text = Pango.parse_markup("<span foreground=\"#999999\">#{Pango.escape(hms)}</span>")
    layout = context.create_pango_layout
    layout.attributes = attr_list
    layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_basic_font])
    layout.text = text
    layout.alignment = Pango::ALIGN_RIGHT
    layout end

  def header(context)
    header_w = width - @icon_width - @margin*3 - @edge*2
    context.save{
      context.translate(@icon_width + @margin*2 + @edge, @margin + @edge)
      context.set_source_rgb(0,0,0)
      hl_layout, hr_layout = header_left(context), header_right(context)
      context.show_pango_layout(hl_layout)
      context.save{
        context.translate(header_w - hr_layout.size[0] / Pango::SCALE, 0)
        if (hl_layout.size[0] / Pango::SCALE) > header_w - hr_layout.size[0] / Pango::SCALE - 20
          r, g, b = get_backgroundcolor
          grad = Cairo::LinearPattern.new(-20, 0, hr_layout.size[0] / Pango::SCALE + 20, 0)
          grad.add_color_stop_rgba(0.0, r, g, b, 0.0)
          grad.add_color_stop_rgba(20.0 / (hr_layout.size[0] / Pango::SCALE + 20), r, g, b, 1.0)
          grad.add_color_stop_rgba(1.0, r, g, b, 1.0)
          context.rectangle(-20, 0, hr_layout.size[0] / Pango::SCALE + 20, hr_layout.size[1] / Pango::SCALE)
          context.set_source(grad)
          context.fill() end
        context.show_pango_layout(hr_layout) } }
  end

  def escaped_main_text
    Pango.escape(messages.first.to_show) end

  def main_message(context = dummy_context)
    attr_list, text = Pango.parse_markup(escaped_main_text)
    layout = context.create_pango_layout
    layout.width = (width - @icon_width - @margin*3 - @edge*2) * Pango::SCALE
    layout.attributes = attr_list
    layout.wrap = Pango::WRAP_CHAR
    layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_reply_font])
    layout.text = text
    layout end

  def render_main_icon(context)
    context.set_source_pixbuf(main_icon)
    context.paint
  end

  def render_outline(context)
    context.save {
      context.pseudo_blur(4) {
        context.fill {
          context.set_source_rgb(*([32767, 32767, 32767]).map{ |c| c.to_f / 65536 })
          context.rounded_rectangle(@edge, @edge, width-@edge*2, height-@edge*2, 4)
        }
      }
      context.fill {
        context.set_source_rgb(*([65535, 65535, 65535]).map{ |c| c.to_f / 65536 })
        context.rounded_rectangle(@edge, @edge, width-@edge*2, height-@edge*2, 4)
      }
    }
  end

  def main_icon
    @main_icon ||= Gdk::WebImageLoader.pixbuf(messages.first[:user][:profile_image_url], icon_width, icon_height){ |pixbuf|
      @main_icon = pixbuf
      helper.on_modify } end

  def message
    helper.message end

  def dummy_context
    Gdk::Pixmap.new(nil, 1, 1, helper.color).create_cairo_context end

  def get_backgroundcolor
    [1.0, 1.0, 1.0]
  end

end
