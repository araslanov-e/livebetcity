# encoding: utf-8
module Providers
  class LiveBetcity < Base
    module All
      def parse(page)

        all_live_bets = page.search(".all")

        unless all_live_bets.empty?

          result = {}

          all_live_bets.search("> table").each do |table|
            sport_and_league = table.previous_element.previous_sibling.to_s # название спорта и лиги

            sport_and_league_array = sport_and_league.split(". ") # разбиваем строку на массив
            sport = sport_and_league_array.first.strip # первый элемент массива - название спорта
            # TODO не всегда название лиги полностью переведены
            league = sport_and_league_array.drop(1).join(". ").strip # остальные элементы, кроме первого - название лиги

            result[sport] ||= {}
            result[sport][league] ||= {}

            # events
            table.search(".lbk").each do |event|

              main_line_values = event.search("td")
              main_line = {}
              n = 1
              event.previous_element.search("td").each_with_index do |name, index|
                # изменяем одинаковые названия полей
                if name.inner_text == "Odds"
                  column_name = name.inner_text + n.to_s
                  n += 1
                else
                  column_name = name.inner_text
                end
                main_line[column_name] = main_line_values[index].inner_text.gsub(/[+]/, '')
              end
              # puts main_line

              # datetime event, home team, away team
              datetime_event = "#{Date.today.to_s}-#{main_line["Time"]}"
              home_team = main_line["Team 1"]
              away_team = main_line["Team 2"]
              full_name = "#{home_team}, #{away_team}, #{datetime_event}"
              result[sport][league][full_name] ||= []

              # totals
              totals = []
              home_team_wins = main_line["X"].blank? ? "ML1" : "1" # теннис, волейбол, баскетбол
              away_team_wins = main_line["X"].blank? ? "ML2" : "2" # теннис, волейбол, баскетбол
              main_period = get_main_period(sport) # период для основного времени

              totals << [main_period, home_team_wins, nil, main_line["1"]] if main_line["1"].present?
              totals << [main_period, away_team_wins, nil, main_line["2"]] if main_line["2"].present?
              totals << [main_period, "1X", nil, main_line["1X"]] if main_line["1X"].present?
              totals << [main_period, "12", nil, main_line["12"]] if main_line["12"].present?
              totals << [main_period, "X2", nil, main_line["X2"]] if main_line["X2"].present?
              totals << [main_period, "F1", main_line["Handicap 1"], main_line["Odds1"]] if main_line["Handicap 1"].present?
              totals << [main_period, "F2", main_line["Handicap 2"], main_line["Odds2"]] if main_line["Handicap 2"].present?
              totals << [main_period, "TO", main_line["Total"], main_line["Over"]] if main_line["Over"].present?
              totals << [main_period, "TU", main_line["Total"], main_line["Under"]] if main_line["Under"].present?

              result[sport][league][full_name] = totals

            end

          end

          puts result

        else
          puts :empty
        end

      end
    end
  end
end