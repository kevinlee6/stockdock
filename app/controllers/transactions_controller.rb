class TransactionsController < ApplicationController
  before_action :sanitize_page_params, only: [:create]
  before_action :validate_params, only: [:create]

  def index
    @transactions = current_user.transactions.order(created_at: :desc)
  end

  def create
    if @errors.length > 0
      respond_to do |format|
        format.html { redirect_to portfolio_index_path, alert: @errors.join("\n") }
        format.js
      end
      return @errors
    end
    
    amt = params[:qty]
    @success = "Transaction successful. You have bought #{amt} share#{amt > 1 ? 's' : ''} of #{params[:ticker]}."

    update_portfolio(ticker: params[:ticker], qty: params[:qty])

    transactions = current_user.transactions
    transaction = transactions.new(transaction_params)

    if transaction.save
      @shares = portfolio.owned_shares
      @balance = 0
      @info = construct_info_hash(@shares) 

      @shares.each do |share|
        ticker = share[:ticker]
        qty = share[:num_shares]
        @balance += @info[ticker]['price'].to_f * qty
      end

      @balance = @balance.floor(2)

      respond_to do |format|
        format.html { redirect_to portfolio_index_path, notice: @success }
        format.js
      end
    else
      respond_to do |format|
        format.html { redirect_to portfolio_index_path, notice: 'Error'}
        format.js
      end
    end
  end

  private
  def validate_params
    @errors = []

    # Validate quantity
    unless params[:qty].between?(1, 2**31-1)
      @errors << 'That is not a valid quantity.'
    end

    # Validate existence (ticker)
    @price = get_price(params[:ticker])
    if @price.zero?
      @errors << 'There is no stock with that ticker symbol, or there is a server problem.'
      return @errors
    end

    # Validate price
    frontend_price = params[:price_per_share]
    margin = frontend_price / @price
    # If what the user sees is greater than current pricing, it will go through.
    # Otherwise allow a 5% margin on pricing based on current price.
    within_bounds = margin >= 0.95
    unless within_bounds
      @errors << 'The price listed on your screen did not match the current price. You may need to pull the most current price.'
    end

    unless validate_affordability?
      @errors << 'There is insufficient funds in your account to complete this transaction.'
    end

    if @errors.length > 0
      @errors << 'No transaction has been made.'
    end

    @errors
  end

  def update_portfolio(ticker:, qty:)
    return portfolio if @price.zero?

    @target_share = portfolio.owned_shares.find_by(ticker: ticker)

    if @target_share
      num_shares_updated = @target_share.num_shares + qty
      @target_share.update!(num_shares: num_shares_updated)
    else
      @target_share = 
        OwnedShare.create!(
          portfolio_id: portfolio.id,
          num_shares: qty,
          ticker: ticker
        )
    end

    update_balance
    portfolio
  end

  def validate_affordability?
    current_user.cash >= purchase_amt
  end

  def update_balance
    new_balance = current_user.cash - purchase_amt
    current_user.update!(cash: new_balance)
  end

  def transaction_params
    params.permit(:ticker, :qty, :price_per_share, :method)
  end

  def purchase_amt
    params[:qty] * @price
  end

  def sanitize_page_params
    params[:ticker].upcase!
    params[:qty] = params[:qty].to_i
    params[:price_per_share] = params[:price_per_share].to_f
    params[:commit].downcase!
    params[:method] = params[:commit]
  end

  def portfolio
    current_user.portfolio
  end
end
