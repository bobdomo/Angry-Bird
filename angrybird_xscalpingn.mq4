bool long_trade          = FALSE;
bool short_trade         = FALSE;
double average_price     = 0;
double i_lots            = 0;
double i_takeprofit      = 0;
double last_buy_price    = 0;
double last_sell_price   = 0;
double price_target      = 0;
double rsi_current       = 0;
double rsi_previous      = 0;
double slip              = 3.0;
extern int rsi_max       = 70.0;
extern int rsi_min       = 40.0;
extern int rsi_period    = 12;
extern int rsi_smoothing = 4;
extern int dev_period    = 12;
extern double rsi_turn   = 0;
extern double exp_base   = 1.5;
extern double lots       = 0.01;
extern double target     = 0.01;
int error                = 0;
int lotdecimal           = 2;
int magic_number         = 2222;
int pipstep              = 0;
int previous_time        = 0;
int total                = 0;
string comment           = "";
string name              = "Ilan1.6";

int init()
{
  Update();
  if (total)
  {
    last_buy_price  = FindLastBuyPrice();
    last_sell_price = FindLastSellPrice();
    UpdateAveragePrice();
    UpdateOpenOrders();
  }
  return (0);
}

int deinit() { return (0); }
int start()
{ /* Sleeps until next bar opens if a trade is made */
  if (!IsOptimization()) Update();
  if (previous_time == Time[0]) return (0);
  previous_time = Time[0];

  /* All the actions that occur when a trade is signaled */
  int indicator_result = IndicatorSignal();
  if (indicator_result > -1)
  {
    Update();
    if (total == 0)
    {
      if (indicator_result == OP_BUY)
        error = OrderSend(Symbol(), OP_BUY, i_lots, Ask, slip, 0, 0, name,
                          magic_number, 0, clrLimeGreen);
      else if (indicator_result == OP_SELL)
        error = OrderSend(Symbol(), OP_SELL, i_lots, Bid, slip, 0, 0, name,
                          magic_number, 0, clrHotPink);

      NewOrdersPlaced();
    }
    else
    {
      if (indicator_result == OP_SELL)
      {
        if (short_trade && Bid > last_sell_price + pipstep * Point)
        {
          error = OrderSend(Symbol(), OP_SELL, i_lots, Bid, slip, 0, 0, name,
                            magic_number, 0, clrHotPink);
          NewOrdersPlaced();
        }
        else if (long_trade && Ask < last_buy_price - pipstep * Point)
        {
          CloseThisSymbolAll();
          error = OrderSend(Symbol(), OP_SELL, i_lots, Bid, slip, 0, 0, name,
                            magic_number, 0, clrHotPink);
          NewOrdersPlaced();
        }
      }
      else if (indicator_result == OP_BUY)
      {
        if (long_trade && Ask < last_buy_price - pipstep * Point)
        {
          error = OrderSend(Symbol(), OP_BUY, i_lots, Ask, slip, 0, 0, name,
                            magic_number, 0, clrLimeGreen);
          NewOrdersPlaced();
        }
        else if (short_trade && Bid > last_sell_price + pipstep * Point)
        {
          CloseThisSymbolAll();
          error = OrderSend(Symbol(), OP_BUY, i_lots, Ask, slip, 0, 0, name,
                            magic_number, 0, clrLimeGreen);
          NewOrdersPlaced();
        }
      }
    }
  }
  return (0);
}

void Update()
{
  total                 = CountTrades();
  pipstep               = 1 * (iStdDev(NULL, 0, dev_period, 0, MODE_SMA, PRICE_TYPICAL, 0) / Point);
  double commission     = CalculateCommission() * -1;
  double all_lots       = CalculateLots();
  double delta          = MarketInfo(Symbol(), MODE_TICKVALUE) * all_lots;
  double lot_multiplier = MathPow(exp_base, (total));
  i_lots                = NormalizeDouble(lots * lot_multiplier, lotdecimal);

  if (total == 0)
  { /* Reset */
    i_takeprofit = 2000;
    short_trade  = FALSE;
    long_trade   = FALSE;
  }
  else
  { /* Zero divide issue*/ /* TODO */
      i_takeprofit = (commission / delta) + (target / delta);
  }

  if (!IsOptimization())
  {
    int tp_dist           = 0;
    int time_difference   = TimeCurrent() - Time[0];
    double order_spread   = 0;

    if (short_trade)
    {
      tp_dist      = (Bid - price_target) / Point;
      order_spread = (last_sell_price - price_target) / Point;
    }
    else if (long_trade)
    {
      tp_dist      = (price_target - Ask) / Point;
      order_spread = (price_target - last_buy_price) / Point;
    }

    name = "RSI: " + NormalizeDouble(rsi_current, lotdecimal) + " | " +
            NormalizeDouble(rsi_previous, lotdecimal) + "\n";
    Comment(
            "RSI: "                   + NormalizeDouble((rsi_current - rsi_previous), lotdecimal) +
        //  " Short | Long: "         + short_trade + " : " + long_trade +
        //  " Next Order: "           + i_lots +
        //  " Average Price: "        + NormalizeDouble(average_price, Digits) +
            " Spread: "               + (int) order_spread +
            " Take Profit: "          + (int) i_takeprofit +
      //    " Take Profit Distance: " + tp_dist +
            " Pipstep: "              + pipstep +
            " Time: "                 + time_difference
           );
  }
}

void NewOrdersPlaced()
{
  if (IsTesting() && error < 0)
  {
    CloseThisSymbolAll();
    error = OrderSend(Symbol(), OP_BUY, AccountFreeMargin() / Bid, Ask, slip, 0, 0, name,
                      magic_number, 0, clrLimeGreen);
    ExpertRemove();
  }
  last_buy_price  = FindLastBuyPrice();
  last_sell_price = FindLastSellPrice();
  Update();
  UpdateAveragePrice();
  UpdateOpenOrders();
}

void UpdateAveragePrice()
{
  average_price = 0;
  double count  = 0;
  for (int i = 0; i < total; i++)
  {
    error = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
    {
      average_price += OrderOpenPrice() * OrderLots();
      count         += OrderLots();
    }
  }
  count         = count         / total;
  average_price = average_price / total;
  average_price = average_price / count;
}

void UpdateOpenOrders()
{
  for (int i = 0; i < total; i++)
  {
    error = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
    {
      if (OrderType() == OP_BUY)
      {
        price_target = average_price + (i_takeprofit * Point);
        short_trade  = FALSE;
        long_trade   = TRUE;
      }
      else if (OrderType() == OP_SELL)
      {
        price_target = average_price - (i_takeprofit * Point);
        short_trade  = TRUE;
        long_trade   = FALSE;
      }
      error = OrderModify(OrderTicket(), NULL,
                          NormalizeDouble(OrderStopLoss(), Digits),
                          NormalizeDouble(price_target, Digits), 0, Yellow);
    }
  }
}

int IndicatorSignal()
{
  rsi_current  = 0;
  rsi_previous = 0;
  for (int i = 0; i < rsi_smoothing; i++)
  {
    rsi_current  += iRSI(NULL, 0, rsi_period, PRICE_TYPICAL, i + 1);
    rsi_previous += iRSI(NULL, 0, rsi_period, PRICE_TYPICAL, i + 2);
  }
  rsi_current  /= rsi_smoothing;
  rsi_previous /= rsi_smoothing;

  if (rsi_current > rsi_max && rsi_current - rsi_previous < rsi_turn) return OP_SELL;
  if (rsi_current < rsi_min && rsi_current - rsi_previous > -rsi_turn) return OP_BUY;
  return (-1);
}

int CountTrades()
{
  int count = 0;
  for (int trade = OrdersTotal() - 1; trade >= 0; trade--)
  {
    error = OrderSelect(trade, SELECT_BY_POS, MODE_TRADES);
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
      if (OrderType() == OP_SELL || OrderType() == OP_BUY) count++;
  }
  return (count);
}

void CloseThisSymbolAll()
{
  for (int trade = OrdersTotal() - 1; trade >= 0; trade--)
  {
    error = OrderSelect(trade, SELECT_BY_POS, MODE_TRADES);
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
    {
      if (OrderType() == OP_BUY)
        error = OrderClose(OrderTicket(), OrderLots(), Bid, slip, Blue);
      if (OrderType() == OP_SELL)
        error = OrderClose(OrderTicket(), OrderLots(), Ask, slip, Red);
    }
  }
}

double CalculateProfit()
{
  double Profit = 0;
  for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
  {
    error = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
      if (OrderType() == OP_BUY || OrderType() == OP_SELL)
        Profit += OrderProfit();
  }
  return (Profit);
}

double CalculateCommission()
{
  double commission = 0;
  for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
  {
    error = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
      if (OrderType() == OP_BUY || OrderType() == OP_SELL)
        commission += OrderCommission();
  }
  return (commission);
}

double CalculateLots()
{
  double lot = 0;
  for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
  {
    error = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
      if (OrderType() == OP_BUY || OrderType() == OP_SELL)
      {
        lot += OrderLots();
      }
  }
  return (lot);
}

double FindLastBuyPrice()
{
  double oldorderopenprice;
  int oldticketnumber;
  int ticketnumber = 0;
  for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
  {
    error = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number &&
        OrderType() == OP_BUY)
    {
      oldticketnumber = OrderTicket();
      if (oldticketnumber > ticketnumber)
      {
        oldorderopenprice = OrderOpenPrice();
        ticketnumber      = oldticketnumber;
      }
    }
  }
  return (oldorderopenprice);
}

double FindLastSellPrice()
{
  double oldorderopenprice;
  int oldticketnumber;
  int ticketnumber = 0;
  for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
  {
    error = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number &&
        OrderType() == OP_SELL)
    {
      oldticketnumber = OrderTicket();
      if (oldticketnumber > ticketnumber)
      {
        oldorderopenprice = OrderOpenPrice();
        ticketnumber      = oldticketnumber;
      }
    }
  }
  return (oldorderopenprice);
}
