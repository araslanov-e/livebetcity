module Providers

  class LiveBetcity < Base

    URL_LIVE_BETS = "http://betcityru.com/live/line.php" # live ставки
    URL_ALL_LIVE_BETS = "http://betcityru.com/livebetssh.php" # все live ставки
    URL_LANGUAGE = "http://betcityru.com/lngswitch.php?lang=%s" # выбор языка
    # Разновидности спорта
    # содержат период в основное время, значение которого зависит от X.present? (есть ничья) [true, false]
    SPORTS = {
      "American Football" => ["-1","-1"],
      "Badminton" => ["0","0"],
      "Bandy" => ["0","0"],
      "Baseball" => ["0","0"],
      "Basketball" => ["-1","-1"],
      "Darts" => ["0","0"],
      "Futsal" => ["0","0"],
      "Handball" => ["0","0"],
      "Hockey" => ["0","-1"],
      "Rugby Union" => ["0","0"],
      "Snooker" => ["0","0"],
      "Table Tennis" => ["-1","-1"],
      "Tennis" => ["-1","-1"],
      "Volleyball" => ["0","0"],
      "Soccer" => ["0","0"]
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
    # draw - true/false
    def get_main_period(sport, draw = false)
      draw ? SPORTS[sport][0] : SPORTS[sport][1]
    end

    private

      def initial_request
        @agent = Mechanize.new
        @agent.get(URL_LANGUAGE % 'en') # выбор английского языка
      end

      def parse_handicaps(line, home_team_or_first_player, away_team_or_second_player)
        # Handicap: BK Prostejov: (-10.5) 1.9; BK Decin: (+10.5) 1.8;
        home_team_or_first_player_matches = line.match(/Handicap:\s?#{Regexp.escape(home_team_or_first_player)}:\s\(([\+\-\d\.]+)\)\s([\d\.]+)/)
        handicap_1, value_1 = home_team_or_first_player_matches ? [home_team_or_first_player_matches[1], home_team_or_first_player_matches[2]] : [nil] * 2

        away_team_or_second_player_matches = line.match(/[:;]\s?#{Regexp.escape(away_team_or_second_player)}:\s\(([\+\-\d\.]+)\)\s([\d\.]+)/)
        handicap_2, value_2 = away_team_or_second_player_matches ? [away_team_or_second_player_matches[1], away_team_or_second_player_matches[2]] : [nil] * 2

        [handicap_1.gsub(/[+]/, ''), value_1, handicap_2.gsub(/[+]/, ''), value_2]
      end

      def parse_totals(line)
        # Total: (134.5) Under 1.8; Over 1.9;
        total_matches = line.match(/Total:\s\(([\d\.]+)\)\s?(Under\s([\d\.]+);)?\s?(Over\s([\d\.]+);)?/)
        total_matches ? [total_matches[1], total_matches[3], total_matches[5]] : [nil] * 3
      end

      def parse_ind_totals(line, home_team_or_first_player, away_team_or_second_player)
        # Ind. Total: BK Prostejov: (71.5) Under 1.87; Over 1.87; BK Decin: (62) Under 1.87; Over 1.87;
        home_team_or_first_player_matches = line.match(/Ind\.\sTotal:\s?#{Regexp.escape(home_team_or_first_player)}:\s\(([\d\.]+)\)\s?(Under\s([\d\.]+);)?\s?(Over\s([\d\.]+);)?/)
        total_1, under_1, over_1 = home_team_or_first_player_matches ? [home_team_or_first_player_matches[1], home_team_or_first_player_matches[3], home_team_or_first_player_matches[5]] : [nil] * 3

        away_team_or_second_player_matches = line.match(/[:;]\s+#{Regexp.escape(away_team_or_second_player)}:\s\(([\d\.]+)\)\s?(Under\s([\d\.]+);)?\s?(Over\s([\d\.]+);)?/)
        total_2, under_2, over_2 = away_team_or_second_player_matches ? [away_team_or_second_player_matches[1], away_team_or_second_player_matches[3], away_team_or_second_player_matches[5]] : [nil] * 3

        [total_1, under_1, over_1, total_2, under_2, over_2]
      end

      def get_totals_over_period(names, values)
        period_line = {} # хеш значений периода
        names.each_with_index do |name, index|
          # в первом столбце - период
          column_name = index.zero? ? "period" : name.inner_text.force_encoding("BINARY").gsub(/\xA0|\xC2/, '').force_encoding("UTF-8") # удаляем \xA0 и \xC2
          next if column_name.empty? # пропускаем другие пустые столбцы
          period_line[column_name] = values[index].inner_text.gsub(/[+]/, '')
        end
        period_line
      end

  end

  class LiveBetcityError < BaseError; end

end