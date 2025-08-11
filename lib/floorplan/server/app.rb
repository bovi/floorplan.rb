# frozen_string_literal: true

begin
  require 'webrick'
rescue LoadError
  warn 'WEBrick not available. Install with: gem install webrick'
  raise
end

require 'thread'
require 'time'
require_relative '../evaluator'
require_relative '../validate'
require_relative '../render/svg_renderer'

module Floorplan
  module Server
    class App
      def initialize(plan_path, host: '127.0.0.1', port: 9393, live: true, theme: :default)
        @plan_path = File.expand_path(plan_path)
        @host = host
        @port = port
        @live = live
        @theme = theme
        @clients = []
        @mutex = Mutex.new
        @stopping = false
      end

      def start
        server = WEBrick::HTTPServer.new(BindAddress: @host, Port: @port, AccessLog: [], Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN))
        trap('INT') { @stopping = true; server.shutdown }
        trap('TERM') { @stopping = true; server.shutdown }

        server.mount_proc('/') { |req, res| serve_index(req, res) }
        server.mount_proc('/plan.svg') { |req, res| serve_svg(req, res) }
        server.mount_proc('/plan.json') { |req, res| serve_json(req, res) }
        server.mount_proc('/health') { |_req, res| res.status = 200; res['Content-Type'] = 'text/plain'; res.body = 'ok' }
        server.mount_proc('/events') { |req, res| serve_sse(req, res) }

        if @live
          @watcher = Thread.new { watch_loop(server) }
        end
        puts "Serving #{@plan_path} on http://#{@host}:#{@port} (live reload: #{@live ? 'on' : 'off'})"
        begin
          server.start
        rescue Interrupt
          @stopping = true
        ensure
          @stopping = true
          @watcher&.kill
          begin
            @mutex.synchronize { @clients.each { |c| write_sse(c, 'shutdown') } }
          rescue StandardError
          end
          server.shutdown rescue nil
        end
      end

      private

      def serve_index(_req, res)
        res['Content-Type'] = 'text/html; charset=utf-8'
        res.body = <<~HTML
          <!DOCTYPE html>
          <meta charset="utf-8" />
          <title>Floorplan Viewer</title>
          <style>
            html, body { height: 100%; margin: 0; font-family: system-ui, sans-serif; }
            header { padding: 8px 12px; background: #111; color: #eee; font-size: 14px; }
            main { height: calc(100% - 40px); display: flex; align-items: center; justify-content: center; background: #f7f7f7; }
            img { max-width: 100%; max-height: 100%; box-shadow: 0 0 0 1px #ddd inset; background: #fff; }
            .error { color: #a00; white-space: pre; padding: 8px; }
          </style>
          <header>
            Floorplan.rb — #{@plan_path} — Live reload #{@live ? 'ON' : 'OFF'}
          </header>
          <main>
            <img id="svg" src="/plan.svg?ts=#{Time.now.to_i}" alt="floorplan" />
          </main>
          <script>
          (function(){
            var img = document.getElementById('svg');
            function reload(){ img.src = '/plan.svg?ts=' + Date.now(); }
            document.addEventListener('keydown', function(e){ if (e.key === 'r') reload(); });
            #{ @live ? "var es = new EventSource('/events'); es.onmessage = function(){ reload(); }; es.onerror = function(){ console.log('SSE disconnected'); };" : ''}
          })();
          </script>
        HTML
      end

      def build_plan
        plan = Floorplan::Evaluator.from_file(@plan_path)
        Floorplan::Validate.check!(plan)
        plan
      end

      def serve_svg(_req, res)
        res['Content-Type'] = 'image/svg+xml; charset=utf-8'
        res['Cache-Control'] = 'no-store'
        begin
          plan = build_plan
          svg = Floorplan::Render::SVGRenderer.new(theme: @theme).render(plan)
          res.body = svg
        rescue Exception => e
          res.status = 200
          res.body = Floorplan::Render::SVGRenderer.new(theme: @theme).send(:error_svg, e)
        end
      end

      def serve_json(_req, res)
        require 'json'
        res['Content-Type'] = 'application/json; charset=utf-8'
        begin
          plan = build_plan
          res.body = JSON.pretty_generate(plan.to_h)
        rescue Exception => e
          res.status = 500
          res.body = JSON.generate({ error: e.message })
        end
      end

      def serve_sse(_req, res)
        res['Content-Type'] = 'text/event-stream'
        res['Cache-Control'] = 'no-cache'
        res.chunked = true
        @mutex.synchronize { @clients << res }
        res.body = ''
        # Keep open until server shutdown or client disconnect
        begin
          ticks = 0
          until @stopping
            sleep 1
            ticks += 1
            write_sse(res, 'ping') if (ticks % 30).zero?
          end
        rescue StandardError
          # client disconnected
        ensure
          @mutex.synchronize { @clients.delete(res) }
        end
      end

      def write_sse(res, data)
        res << "data: #{data}\n\n"
      rescue StandardError
        # ignore broken pipe; cleanup elsewhere
      end

      def watch_loop(server)
        last_mtime = File.mtime(@plan_path) rescue Time.at(0)
        loop do
          break if @stopping
          sleep 0.3
          m = File.mtime(@plan_path) rescue last_mtime
          next if m <= last_mtime
          last_mtime = m
          @mutex.synchronize do
            @clients.each { |c| write_sse(c, 'change') }
          end
        end
      end
    end
  end
end
