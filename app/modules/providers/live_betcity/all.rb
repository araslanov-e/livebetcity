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

            next if SPORTS[sport].blank? # пропускаем, если информация по данному спорту не нужны

            result[sport] ||= {}
            result[sport][league] ||= {}

            # events
            table.search(".lbk").each do |event|

              main_line_values = event.search("td") # значения основного периода
              main_line = {} # хеш значений основного периода
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

              # datetime event, home team, away team
              datetime_event = "#{Date.today.to_s}-#{main_line["Time"]}"
              home_team = main_line["Team 1"]
              away_team = main_line["Team 2"]
              first_player = main_line["Player 1"]
              second_player = main_line["Player 2"]

              # команды или игроки
              home_team_or_first_player = home_team || first_player
              away_team_or_second_player = away_team || second_player

              full_name = "#{home_team_or_first_player}, #{away_team_or_second_player}, #{datetime_event}"
              result[sport][league][full_name] ||= []

              # totals
              totals = []
              home_team_or_first_player_wins = main_line["X"].present? ? "1" : "ML1" # теннис, волейбол, баскетбол
              away_team_or_second_player_wins = main_line["X"].present? ? "2" : "ML2" # теннис, волейбол, баскетбол
              main_period = get_main_period(sport, main_line["X"].present?) # период для основного времени

              totals << [main_period, home_team_or_first_player_wins, nil, main_line["1"]] if main_line["1"].present?
              totals << [main_period, away_team_or_second_player_wins, nil, main_line["2"]] if main_line["2"].present?
              totals << [main_period, "1X", nil, main_line["1X"]] if main_line["1X"].present?
              totals << [main_period, "12", nil, main_line["12"]] if main_line["12"].present?
              totals << [main_period, "X2", nil, main_line["X2"]] if main_line["X2"].present?
              totals << [main_period, "F1", main_line["Handicap 1"], main_line["Odds1"]] if main_line["Handicap 1"].present?
              totals << [main_period, "F2", main_line["Handicap 2"], main_line["Odds2"]] if main_line["Handicap 2"].present?
              totals << [main_period, "TO", main_line["Total"], main_line["Over"]] if main_line["Over"].present?
              totals << [main_period, "TU", main_line["Total"], main_line["Under"]] if main_line["Under"].present?

              # additional lines
              lines_nodes = event.next_element # tr

              # handicaps
              lines_nodes.search('./td/div[b="Handicap:"]').each do |h|
                handicap_1, value_1, handicap_2, value_2 = parse_handicaps(h.content, home_team_or_first_player, away_team_or_second_player)
                totals << [main_period, "F1", handicap_1, value_1] if handicap_1 && value_1 # handicap 1
                totals << [main_period, "F2", handicap_2, value_2] if handicap_2 && value_2 # handicap 2
              end

              # totals
              lines_nodes.search('./td/div[b="Total:"]').each do |t|
                total, under, over = parse_totals(t.content)
                if total # notice: totals can be the same as in the basic line
                  totals << [main_period, "TO", total, over] if over
                  totals << [main_period, "TU", total, under] if under
                end
              end

              # both to score
              lines_nodes.search('./td/div[b="Both teams to score or one scoreless:"]').each do |bts|
                bts_matches = bts.content.match(/Both score:\s([\d\.]+); One scoreless:\s([\d\.]+)/)
                bts_y_value, bts_n_value = bts_matches ? [bts_matches[1], bts_matches[2]] : nil * 2
                totals << [main_period, "BTS_Y", nil, bts_y_value] if bts_y_value
                totals << [main_period, "BTS_N", nil, bts_n_value] if bts_n_value
              end

              # even/odd
              lines_nodes.search('./td/div[b="Even/Odd Total:"]').each do |event_odd|
                event_odd_matches = event_odd.content.match(/Even:\s([\d\.]+); Odd:\s([\d\.]+)/)
                even_value, odd_value = event_odd_matches ? [event_odd_matches[1], event_odd_matches[2]] : nil * 2
                totals << [main_period, "EVEN", nil, even_value] if even_value
                totals << [main_period, "ODD", nil, odd_value] if odd_value
              end

              # individual totals
              lines_nodes.search('./td/div[b="Ind. Total:"]').each do |it|
                total_1, under_1, over_1, total_2, under_2, over_2 = parse_ind_totals(it.content, home_team_or_first_player, away_team_or_second_player)
                # home_team_or_first_player
                if total_1
                  totals << [main_period, "I1TO", total_1, over_1] if over_1
                  totals << [main_period, "I1TU", total_1, under_1] if under_1
                end
                # away_team_or_second_player
                if total_2
                  totals << [main_period, "I2TO", total_2, over_2] if over_2
                  totals << [main_period, "I2TU", total_2, under_2] if under_2
                end
              end

              # периоды
              # search("table#dt")
              lines_nodes.search('./td/table[@id="dt"]').each do |periods|
                # строки таблицы
                columns_name = []
                periods.search("tr").each_with_index do |line, number_line|
                  case number_line
                    when 0 # title table
                      next
                    when 1 # column name
                      columns_name = line.search("td.tdh")
                    else # other line
                      period_totals = line.search("td")
                      totals += get_totals_over_period(columns_name, period_totals) # исходны для периодов
                  end
                end
              end

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