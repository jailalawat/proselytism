class Proselytism::Converters::OpenOffice < Proselytism::Converters::Base

  class Error < parent::Base::Error; end

  from  :odt, :doc, :rtf, :sxw, :docx, :txt, :html, :htm, :wps
  to    :odt, :doc, :rtf, :pdf, :txt, :html, :htm, :wps

  module Bridges
    module JOD
      def self.command
        "java -jar #{File.expand_path('open_office/odconverters/jodconverter-2.2.2/lib/jodconverter-cli-2.2.2.jar', File.dirname(__FILE__))}"
      end
    end
    module PYOD
      def self.command
        "python #{File.expand_path('open_office/odconverters/pyodconverter.py', File.dirname(__FILE__))}"
      end
    end
  end

  # Converts documents
  def perform(origin, options={})
    destination = destination_file_path(origin, options)
    command = "#{Proselytism::Converters::OpenOffice}::Bridges::#{config.oo_server_bridge}".constantize.command + " '#{origin}' '#{destination}' 2>&1"
    server.perform { execute(command) }
    destination
  end

  # For unknown reason sometimes OpenOffice converts in ISO-8859-1,
  # post process to ensure a conversion in UTF-8 when :to => :txt
  def perform_with_ensure_utf8(origin, options={})
    destination = perform_without_ensure_utf8(origin, options)
    if options[:to].to_s == "txt" and `file #{destination}` =~ /ISO/
      #lookup_on = Iconv.new('ASCII//TRANSLIT','UTF-8').iconv(str).upcase.strip.gsub(/'/, " ")
      #log :warn, "***OOO has converted file in "
      tmp_iconv_file = "#{destination}-tmp_iconv.txt"
      execute("iconv --from-code ISO-8859-1 --to-code UTF-8 #{destination} > #{tmp_iconv_file} && mv #{tmp_iconv_file} #{destination}")
    end
    destination
  end

  alias_method_chain :perform, :ensure_utf8

  def server
    Server.instance
  end


  class Server
    include Singleton
    class Error < Proselytism::Converters::OpenOffice::Error; end

    delegate :config, :log, :to => Proselytism

    # Run a block with a timeout and retry if the first execution fails
    def perform(&block)
      attempts = 1
      begin
        ensure_available
        block.call
        #Timeout::timeout(config.oo_conversion_max_time,&block)
      rescue Timeout::Error, Proselytism::Converters::OpenOffice::Error
        attempts += 1
        restart!
        retry unless attempts > config.oo_conversion_max_tries
        raise Error, "OpenOffice server perform timeout"
      end
    end

    # Restart if running or start new instance
    def restart!
      stop! if running?
      start!
    end

    # Start new instance
    def start!
      log :debug, "OpenOffice server started" do
        system "#{config.open_office_path} --headless --accept=\"socket,host=127.0.0.1,port=8100\;urp\;\" --nofirststartwizard --nologo --nocrashreport --norestore --nolockcheck --nodefault &"
        begin
          Timeout.timeout(3) do
            while !running?
              log :debug, ". Waiting OpenOffice server to run"
              sleep(0.1)
            end
          end
        rescue
          raise Error, "Could not start OpenOffice"
        end
        # OpenOffice needs some time to wake up
        sleep(config.oo_server_start_delay)
      end
      nil
    end

    def start_with_running_control!
      if running?
        log :debug, "OpenOffice server is allready running"
      else
        start_without_running_control!
      end
    end
    alias_method_chain :start!, :running_control

    # Kill running instance
    def stop!
      #operating_system = `uname -s`
      #command = "killall -u `whoami` -#{operating_system == "Linux" ? 'q' : 'm'} soffice"
      begin
        Timeout::timeout(3) do
          loop do
            system("killall -9 soffice > /dev/null 2>&1")
            system("killall -9 soffice.bin > /dev/null 2>&1")
            break unless running?
          end
        end
      rescue Timeout::Error
        raise Error, "Could not kill OpenOffice !!"
      ensure
        # Remove user profile
        system("rm -rf ~/openoffice.org*")
        log :debug, "OpenOffice server stopped"
      end
    end

    def stop_with_running_control!
      if !running?
        log :debug, "OpenOffice server is allready stoped"
      else
        stop_without_running_control!
      end
    end
    alias_method_chain :stop!, :running_control

    # Is OpenOffice server running?
    def running?
      !`pgrep soffice`.blank?
    end


    # Is the current instance stuck ?
    def stalled?
      begin
        Timeout.timeout config.oo_server_max_cpu_delay do
          loop do
            cpu_usage = `ps -Ao pcpu,pid,comm= | grep soffice`.split(/\n/).map{|usage| /^\s*\d+/.match(usage)[0].strip.to_i}
            break unless cpu_usage.all?{|usage| usage > config.oo_server_max_cpu }
            sleep(0.2)
          end
        end
        false
      rescue
        log :error, "OpenOffice server stalled : \n---\n" + `ps -Ao pcpu,pid,comm | grep soffice` + "\n---"
        true
      end
    end

    def available?
      `ps -o pid,stat,command |grep soffice`.match(/\d+\s(\w)/i)[1] == "S"
    end

    # Make sure there will be an available instance
    def ensure_available
      start! unless running?
      restart! if stalled?
      begin
        Timeout.timeout config.oo_server_availability_delay do
          while !available?
            log :debug, ". Waiting OpenOffice server availability"
            sleep(0.5)
          end
        end
      rescue Timeout::Error
        raise Error, "OpenOffice Server unavailable"
      end
      true
    end

  end



end

