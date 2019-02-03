def get_batch_price(arr)
  JSON.parse(HTTParty.get("https://api.iextrading.com/1.0/stock/market/batch?symbols=#{arr.join(',')}&types=price").body)
end

tickers = %w[AAPL MSFT TSLA GOOG AMZN IBM S B AMD GE]
prices = get_batch_price(tickers)

u1 = User.create!(
  name: 'Kevin',
  email: 'kevin@gmail.com',
  password: 'password',
  cash: 50000
)

tickers.each do |ticker|
  qty = rand(1..21)
  u1.transactions.create!(
    ticker: ticker,
    qty: qty,
    price_per_share: prices[ticker]['price'].to_f.floor(2) 
    method: 'buy'
  )
  u1.portfolio.owned_shares.create!(
    ticker: ticker,
    num_shares: qty
  )
end
