#include "subroutines.mqh"

bool long_trade = FALSE;
bool new_orders_placed = FALSE;
bool short_trade = FALSE;
bool trade_now = FALSE;
double average_price = 0;
double buy_limit = 0;
double i_lots = 0;
double last_buy_price = 0;
double last_sell_price = 0;
double lot_multiplier = 0;
double price_target = 0;
double sell_limit = 0;
double slip = 3.0;
double tp_dist = 0;
int lotdecimal = 2;
int magic_number = 2222;
int max_trades = 100;
int num_of_trades = 0;
int ticket = 0;
int timeprev = 0;
int total = 0;
string name = "Ilan1.6";
string order_comment = "";
extern double i_maximum = 80.0;
extern double i_minimum = 20.0;
extern double lots = 0.01;
extern double takeprofit = 1300.0;
extern int i_period = 11;
extern int exp_base = 3;

int init() { return (0); }
int deinit() { return (0); }
void Update()
{
  last_buy_price = FindLastBuyPrice();
  last_sell_price = FindLastSellPrice();
  RefreshRates();
  order_comment = name + "-" + num_of_trades;
  total = CountTrades();
  sell_limit = Bid;
  buy_limit = Ask;

  if (long_trade) tp_dist = (price_target - Ask) / Point;
  if (short_trade) tp_dist = (Bid - price_target) / Point;

  if (tp_dist < takeprofit)
    lot_multiplier = 1;
  else
    lot_multiplier = MathPow(exp_base, (tp_dist / takeprofit));

  Comment("Distance to Take Profit: " + tp_dist + "\nLot multiplier: " +
          lot_multiplier);
}

int start()
{
  Update();
  if (timeprev == Time[0]) return (0);
  timeprev = Time[0];

  for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
  {
    if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) CheckError();
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
    {
      if (OrderType() == OP_BUY)
      {
        long_trade = TRUE;
        short_trade = FALSE;
        break;
      }

      if (OrderType() == OP_SELL)
      {
        long_trade = FALSE;
        short_trade = TRUE;
        break;
      }
    }
  }

  if (total > 0 && total <= max_trades)
  {
    Update();

    if (short_trade && Bid > last_sell_price + 0.5)
    {
      if (IsIndicatorHigh())
        trade_now = TRUE;
      else
        trade_now = FALSE;
    }

    if (long_trade && Ask < last_buy_price - 0.5)
    {
      if (IsIndicatorLow())
        trade_now = TRUE;
      else
        trade_now = FALSE;
    }
  }

  if (total < 1)
  {
    short_trade = FALSE;
    long_trade = FALSE;
    trade_now = TRUE;
  }

  if (trade_now)
  {
    Update();

    if (total < 1 && !short_trade && !long_trade)
    {
      if (IsIndicatorHigh())
      {  // Sell
        num_of_trades = total;
        i_lots = GetLots();
        ticket = OpenPendingOrder(1, i_lots, sell_limit, slip, sell_limit, 0, 0,
                                  order_comment, magic_number, 0, HotPink);
        last_buy_price = FindLastBuyPrice();
        new_orders_placed = TRUE;
        trade_now = FALSE;
      }
      if (IsIndicatorLow())
      {  // Buy
        num_of_trades = total;
        i_lots = GetLots();
        ticket = OpenPendingOrder(0, i_lots, buy_limit, slip, buy_limit, 0, 0,
                                  order_comment, magic_number, 0, Lime);
        last_sell_price = FindLastSellPrice();
        new_orders_placed = TRUE;
        trade_now = FALSE;
      }
    }

    if (short_trade)
    {
      num_of_trades = total;
      i_lots = GetLots();
      Update();

      ticket = OpenPendingOrder(1, i_lots, Bid, slip, Ask, 0, 0, order_comment,
                                magic_number, 0, HotPink);
      last_sell_price = FindLastSellPrice();
      trade_now = FALSE;
      new_orders_placed = TRUE;
    }
    if (long_trade)
    {
      num_of_trades = total;
      i_lots = GetLots();
      Update();
      ticket = OpenPendingOrder(0, i_lots, Ask, slip, Bid, 0, 0, order_comment,
                                magic_number, 0, Lime);
      last_buy_price = FindLastBuyPrice();
      trade_now = FALSE;
      new_orders_placed = TRUE;
    }

    if (ticket < 0)
    {
      CheckError();
      return (-1);
    }
  }

  /******************************************************************************************/
  /******************************************************************************************/

  total = CountTrades();
  average_price = 0;
  double Count = 0;

  for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
  {
    if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) CheckError();
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
    {
      if (OrderType() == OP_BUY || OrderType() == OP_SELL)
      {
        average_price += OrderOpenPrice() * OrderLots();
        Count += OrderLots();
      }
    }
  }

  if (total > 0) average_price = NormalizeDouble(average_price / Count, Digits);

  if (new_orders_placed)
  {
    for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
    {
      if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) CheckError();

      if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
      {
        if (OrderType() == OP_BUY)
          price_target = average_price + takeprofit * Point;
        if (OrderType() == OP_SELL)
          price_target = average_price - takeprofit * Point;

        if (!OrderModify(OrderTicket(), NormalizeDouble(average_price, Digits),
                         NormalizeDouble(OrderStopLoss(), Digits),
                         NormalizeDouble(price_target, Digits), 0, Yellow))
          CheckError();
      }

      new_orders_placed = FALSE;
    }
  }
  Update();
  return (0);
}
