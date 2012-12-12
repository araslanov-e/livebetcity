namespace :live_betcity do
  namespace :import do

    desc "Imports all lines"
    task all: :environment do
      provider = Providers::LiveBetcity.new(:all)
      provider.get_bet_lines
    end
  end
end

