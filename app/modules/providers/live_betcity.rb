module Providers

  class LiveBetcity < Base

    URL_LIVE_BETS = "http://betcityru.com/live/line.php" # live ставки
    URL_ALL_LIVE_BETS = "http://betcityru.com/livebetssh.php" # все live ставки
    URL_LANGUAGE = "http://betcityru.com/lngswitch.php?lang=%s" # выбор языка
    MAIN_PERIOD = {
      "American Football" => "-1",
      "Badminton" => "0",
      "Bandy" => "0",
      "Baseball" => "0",
      "Basketball" => "-1",
      "Darts" => "0",
      "Futsal" => "0",
      "Handball" => "0",
      #"Hockey" => 0, -1
      "Hockey" => "0",
      "Rugby Union" => "0",
      "Snooker" => "0",
      "Table Tennis" => "-1",
      "Tennis" => "-1",
      "Volleyball" => "0",
      "Soccer" => "0"
    }

    def initialize(sport = :soccer)
      super(sport)
    end

    def get_bet_lines()

      begin
        initial_request
      rescue Exception => e
        logger.fatal("Error making initial request: #{e.message}") and return
      end

      begin
        # поскольку на URL_ALL_LIVE_BETS сразу не попасть,
        # на URL_LIVE_BETS необходимо активировать форму id="f2"
        page_live_bets = @agent.get(URL_LIVE_BETS)
        page_all_live_bets = page_live_bets.form_with(:id => 'f2').submit
      rescue Exception => e
        logger.fatal("Error requesting #{URL_LIVE_BETS}: #{e.message}") and return
      end

      parse(page_all_live_bets)
      #parse(a.get("http://localhost:3000/livebetssh.html"))
    end

    # период для основного времени
    def get_main_period(sport)
      MAIN_PERIOD[sport]
    end

    private

      def initial_request
        @agent = Mechanize.new
        @agent.get(URL_LANGUAGE % 'en') # выбор английского языка
      end

  end

  class LiveBetcityError < BaseError; end

end