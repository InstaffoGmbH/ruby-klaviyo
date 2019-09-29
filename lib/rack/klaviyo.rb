module Rack
  class Klaviyo
    def initialize(app, api_key, options={})
      @app = app
      @api_key = api_key
      @options = {
        :insert_js_last => true
      }.merge(options)
    end

    def call(env)
      @env = env

      @status, @headers, @response = @app.call(env)

      if is_trackable_response?
        update_response!
        update_content_length!
      end

      [@status, @headers, @response]
    end

    private

    def update_response!
      @response.each do |part|
        insert_at = part.index(@options[:insert_js_last] ? '</body' : '</head')
        unless insert_at.nil?
          part.insert(insert_at, render_script)
        end
      end
    end

    def update_content_length!
      new_size = 0
      @response.each{|part| new_size += part.bytesize}
      @headers.merge!('Content-Length' => new_size.to_s)
    end

    def is_ajax_request?
      @env.has_key?('HTTP_X_REQUESTED_WITH') && @env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    end

    def is_html_response?
      @headers['Content-Type'].include?('text/html') if @headers.has_key?('Content-Type')
    end

    def is_trackable_response?
      is_html_response? && !is_ajax_request?
    end

    def render_script
      <<-EOT
      <script
        async type="text/javascript"
        src="//static.klaviyo.com/onsite/js/klaviyo.js?company_id=#{@api_key}"
      ></script>
      <script>
        var _learnq = _learnq || [];

        _learnq.push(['identify', {
          // Change the line below to dynamically print the user's email.
          '$email' : '{{ email }}'
        }]);
      </script>
      EOT
    end
  end
end
