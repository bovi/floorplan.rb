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
        server = WEBrick::HTTPServer.new(
          BindAddress: @host,
          Port: @port,
          AccessLog: [],
          Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN),
          DoNotReverseLookup: true,
          RequestTimeout: 3600
        )
        trap('INT') { @stopping = true; server.shutdown }
        trap('TERM') { @stopping = true; server.shutdown }

        server.mount_proc('/') { |req, res| serve_index(req, res) }
        server.mount_proc('/plan.svg') { |req, res| serve_svg(req, res) }
        server.mount_proc('/plan.json') { |req, res| serve_json(req, res) }
        server.mount_proc('/mtime') { |_req, res| serve_mtime(res) }
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
            html, body { height: 100%; margin: 0; font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif; }
            header { padding: 8px 12px; background: #111; color: #eee; font-size: 14px; display:flex; gap:12px; align-items:center; }
            header .spacer { flex: 1; }
            header .btn { cursor: pointer; background:#333; color:#eee; border:1px solid #444; padding:2px 6px; border-radius:3px; font-size:12px; }
            main { height: calc(100% - 40px); background: #f3f4f6; position: relative; overflow: hidden; }
            #viewport { position:absolute; inset:0; overflow:hidden; }
            #stage { transform-origin: 0 0; will-change: transform; }
            #svg { display:block; background:#fff; box-shadow: 0 0 0 1px #ddd inset; user-select:none; pointer-events:none; }
            .hud { position:absolute; right:8px; bottom:8px; background:rgba(0,0,0,.5); color:#fff; padding:4px 6px; border-radius:3px; font-size:12px; }
          </style>
          <header>
            <div>Floorplan.rb — #{@plan_path} — Live reload #{@live ? 'ON' : 'OFF'}</div>
            <div class="spacer"></div>
            <button class="btn" id="fitBtn" title="Fit to window (1)">Fit</button>
            <button class="btn" id="resetBtn" title="Reset (0)">Reset</button>
            <button class="btn" id="zoomInBtn" title="Zoom in (+)">+</button>
            <button class="btn" id="zoomOutBtn" title="Zoom out (-)">−</button>
          </header>
          <main>
            <div id="viewport">
              <div id="stage">
                <img id="svg" src="/plan.svg?ts=#{Time.now.to_i}" alt="floorplan" />
              </div>
              <div class="hud" id="hud">100%</div>
            </div>
          </main>
          <script>
          (function(){
            var img = document.getElementById('svg');
            var viewport = document.getElementById('viewport');
            var stage = document.getElementById('stage');
            var hud = document.getElementById('hud');
            var zoomInBtn = document.getElementById('zoomInBtn');
            var zoomOutBtn = document.getElementById('zoomOutBtn');
            var fitBtn = document.getElementById('fitBtn');
            var resetBtn = document.getElementById('resetBtn');

            function reload(){ img.src = '/plan.svg?ts=' + Date.now(); }
            document.addEventListener('keydown', function(e){ if (e.key === 'r') reload(); });

            var scale = 1, tx = 0, ty = 0;
            var userAdjusted = false;
            function apply(){ stage.style.transform = 'translate(' + tx + 'px,' + ty + 'px) scale(' + scale + ')'; hud.textContent = Math.round(scale*100) + '%'; }

            function fit(){
              var vw = viewport.clientWidth, vh = viewport.clientHeight;
              var iw = img.naturalWidth || img.width; var ih = img.naturalHeight || img.height;
              if (!iw || !ih) return;
              scale = Math.min(vw/iw, vh/ih);
              var w = iw * scale, h = ih * scale;
              tx = (vw - w)/2; ty = (vh - h)/2;
              userAdjusted = false; apply();
            }
            function reset(){ scale = 1; tx = 0; ty = 0; userAdjusted = false; apply(); }
            function zoomAt(screenX, screenY, k){
              var old = scale; var ns = Math.min(20, Math.max(0.1, old * k));
              var rect = viewport.getBoundingClientRect();
              var sx = screenX - rect.left; var sy = screenY - rect.top;
              var kk = ns/old;
              tx = (1-kk)*sx + kk*tx;
              ty = (1-kk)*sy + kk*ty;
              scale = ns; userAdjusted = true; apply();
            }
            function zoomStep(dir){ zoomAt(viewport.clientWidth/2, viewport.clientHeight/2, dir>0 ? 1.2 : 1/1.2); }

            // Mouse wheel zoom
            viewport.addEventListener('wheel', function(e){ e.preventDefault(); var d = e.deltaY>0 ? -1 : 1; var f = d>0 ? 1.1 : 1/1.1; zoomAt(e.clientX, e.clientY, f); }, { passive: false });
            // Drag to pan
            var dragging=false, lx=0, ly=0;
            viewport.addEventListener('mousedown', function(e){ dragging=true; lx=e.clientX; ly=e.clientY; e.preventDefault(); });
            window.addEventListener('mousemove', function(e){ if(!dragging) return; var dx=e.clientX-lx, dy=e.clientY-ly; lx=e.clientX; ly=e.clientY; tx+=dx; ty+=dy; userAdjusted=true; apply(); });
            window.addEventListener('mouseup', function(){ dragging=false; });
            // Buttons
            zoomInBtn.addEventListener('click', function(){ zoomStep(1); });
            zoomOutBtn.addEventListener('click', function(){ zoomStep(-1); });
            fitBtn.addEventListener('click', fit);
            resetBtn.addEventListener('click', reset);
            // Keys
            document.addEventListener('keydown', function(e){
              if(e.key === '+'){ zoomStep(1); }
              else if(e.key === '-'){ zoomStep(-1); }
              else if(e.key === '0'){ reset(); }
              else if(e.key === '1'){ fit(); }
            });
            // Fit on first load and when image changes unless user adjusted
            img.addEventListener('load', function(){ if (!userAdjusted) fit(); });
            window.addEventListener('resize', function(){ if (!userAdjusted) fit(); });

            var live = #{@live ? 'true' : 'false'};
            var es; var pollHandle; var lastMTime = 0;
            function checkMTime(){
              fetch('/mtime', {cache:'no-store'}).then(function(r){ return r.text(); }).then(function(t){
                var ts = parseInt(t, 10) || 0;
                if (ts && ts !== lastMTime) { lastMTime = ts; reload(); }
              }).catch(function(){});
            }
            pollHandle = setInterval(checkMTime, 1000);
            if (live) {
              try {
                es = new EventSource('/events');
                es.addEventListener('change', function(){ reload(); });
                es.addEventListener('ping', function(){});
                es.onerror = function(){ try { es.close(); } catch(_e){} };
              } catch(e) { /* ignore; polling handles reloads */ }
            }
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

      def serve_mtime(res)
        res['Content-Type'] = 'text/plain; charset=utf-8'
        res['Cache-Control'] = 'no-store'
        ts = (File.mtime(@plan_path).to_i rescue 0)
        res.body = ts.to_s
      end

      def serve_sse(_req, res)
        res['Content-Type'] = 'text/event-stream'
        res['Cache-Control'] = 'no-cache'
        res['Connection'] = 'keep-alive'
        res.chunked = true
        @mutex.synchronize { @clients << res }
        res.body = ''
        # initial handshake
        write_sse(res, 'ping', event: 'ping')
        # Keep open until server shutdown or client disconnect
        begin
          ticks = 0
          until @stopping
            sleep 1
            ticks += 1
            write_sse(res, 'ping', event: 'ping') if (ticks % 15).zero?
          end
        rescue StandardError
          # client disconnected
        ensure
          @mutex.synchronize { @clients.delete(res) }
        end
      end

      def write_sse(res, data, event: 'message')
        res << "event: #{event}\n"
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
            @clients.each { |c| write_sse(c, '1', event: 'change') }
          end
        end
      end
    end
  end
end
