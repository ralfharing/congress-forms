require 'thread'

class FillHandler
  def initialize c
    @c = c
  end

  def create_thread fields={}, campaign_tag
    @thread = Thread.new do
      begin
        if DELAY_ALL_NONCAPTCHA_FILLS and not @c.has_captcha?
          @c.delay.fill_out_form fields, campaign_tag
          @result = true
        else
          @result = @c.fill_out_form fields, campaign_tag do |c|
            @result = c
            Thread.stop
            @answer
          end
        end
      rescue Exception => e
        @result = false
      end
      ActiveRecord::Base.connection.close
    end
  end

  def fill fields={}, campaign_tag
    create_thread fields, campaign_tag

    while not defined? @result
      Thread.pass
    end

    FillHandler::check_result @result
  end

  def fill_captcha answer
    return false unless @thread

    @answer = answer
    @thread.run
    @thread.join

    FillHandler::check_result @result
  end

  def self.check_result result
    case result
    when true
      {status: "success"}
    when false
      {status: "error", message: "An error has occurred while filling out the remote form."}
    else
      {status: "captcha_needed", url: result}
    end
  end
end
