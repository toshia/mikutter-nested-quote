# -*- coding: utf-8 -*-

class Gdk::NestedQuote < Gdk::SubParts
  #regist

  TWEET_URL = /^https?:\/\/twitter.com\/(?:#!\/)?[a-zA-Z0-9_]+\/status(?:es)?\/(\d+)(?:\?.*)?$/
  attr_reader :icon_width, :icon_height

  def initialize(*args)
    super
    @icon_width, @icon_height, @margin, @edge = 32, 32, 2, 8
    @message_got = false
    if not get_tweet_ids.empty?
      Deferred.when(*get_tweet_ids.map{ |message_id|
                      Thread.new {Message.findbyid(message_id.to_i) }
                    }).next(&method(:render_message)).terminate end
    if message and not helper.visible?
      sid = helper.ssc(:expose_event, helper){
        helper.on_modify
        helper.signal_handler_disconnect(sid)
        false } end
  end

  def render_message(messages)
    notice messages
    if not helper.destroyed?
      @message_got = true
      @messages = messages
      helper.on_modify
      helper.reset_height end
  end

  def render(context)
    if helper.visible? and messages
      render_outline(context)
      context.save {
        context.translate(@margin+@edge, @margin+@edge)
        render_main_icon(context)
        context.translate(@icon_width + @margin, 0)
        context.set_source_rgb(*([0,0,0]).map{ |c| c.to_f / 65536 })
        context.show_pango_layout(main_message(context)) }
    end
  end

  def height
    if not(helper.destroyed?) and has_tweet_url?
      icon_height + (@margin+@edge)*2
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

  def escaped_main_text
    Pango.escape(messages.first.to_show) end

  def main_message(context = dummy_context)
    attr_list, text = Pango.parse_markup(escaped_main_text)
    layout = context.create_pango_layout
    layout.width = (width - @icon_width - @margin - @edge*2) * Pango::SCALE
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

end
