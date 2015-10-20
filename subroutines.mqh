int CountTrades() {
  int count = 0;

  for (int trade = OrdersTotal() - 1; trade >= 0; trade--) {
    error = OrderSelect(trade, SELECT_BY_POS, MODE_TRADES);
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
      if (OrderType() == OP_SELL || OrderType() == OP_BUY) count++;
  }
  return (count);
}

void CloseThisSymbolAll() {
  for (int trade = OrdersTotal() - 1; trade >= 0; trade--) {
    error = OrderSelect(trade, SELECT_BY_POS, MODE_TRADES);
    if (OrderSymbol() == Symbol()) {
      if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number) {
        if (OrderType() == OP_BUY)
          error = OrderClose(OrderTicket(), OrderLots(), Bid, slip, Blue);
      }
      if (OrderType() == OP_SELL)
        error = OrderClose(OrderTicket(), OrderLots(), Ask, slip, Red);
    }
    Sleep(1000);
  }
}

double CalculateProfit() {
  double Profit = 0;
  for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
    error = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
      if (OrderType() == OP_BUY || OrderType() == OP_SELL)
        Profit += OrderProfit();
  }
  return (Profit);
}

double FindLastBuyPrice() {
  double oldorderopenprice;
  int oldticketnumber;
  int ticketnumber = 0;
  for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
    error = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number &&
        OrderType() == OP_BUY) {
      oldticketnumber = OrderTicket();
      if (oldticketnumber > ticketnumber) {
        oldorderopenprice = OrderOpenPrice();
        ticketnumber = oldticketnumber;
      }
    }
  }
  return (oldorderopenprice);
}

double FindLastSellPrice() {
  double oldorderopenprice;
  int oldticketnumber;
  int ticketnumber = 0;
  for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
    error = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number &&
        OrderType() == OP_SELL) {
      oldticketnumber = OrderTicket();
      if (oldticketnumber > ticketnumber) {
        oldorderopenprice = OrderOpenPrice();
        ticketnumber = oldticketnumber;
      }
    }
  }
  return (oldorderopenprice);
}

double GetLots() { return NormalizeDouble(lots * lot_multiplier, lotdecimal); }

double StopLong(double price, int stop) {
  if (stop == 0)
    return (0);
  else
    return (price - stop * Point);
}

double StopShort(double price, int stop) {
  if (stop == 0)
    return (0);
  else
    return (price + stop * Point);
}

double TakeLong(double price, int stop) {
  if (stop == 0)
    return (0);
  else
    return (price + stop * Point);
}

double TakeShort(double price, int stop) {
  if (stop == 0)
    return (0);
  else
    return (price - stop * Point);
}

int OpenPendingOrder(int pType, double pLots, double pLevel, int sp, double pr,
                     int sl, int tp, string pComment, int pMagic, int pDatetime,
                     color pColor) {
  int c = 0;
  int NumberOfTries = 100;

  switch (pType) {
    case 2:
      for (c = 0; c < NumberOfTries; c++) {
        error = OrderSend(Symbol(), OP_BUYLIMIT, pLots, pLevel, sp,
                          StopLong(pr, sl), TakeLong(pLevel, tp), pComment,
                          pMagic, pDatetime, pColor);
        break;
      }
      break;
    case 4:
      for (c = 0; c < NumberOfTries; c++) {
        error = OrderSend(Symbol(), OP_BUYSTOP, pLots, pLevel, sp,
                          StopLong(pr, sl), TakeLong(pLevel, tp), pComment,
                          pMagic, pDatetime, pColor);
        break;
      }
      break;
    case 0:
      for (c = 0; c < NumberOfTries; c++) {
        RefreshRates();
        error = OrderSend(Symbol(), OP_BUY, pLots, NormalizeDouble(Ask, Digits),
                          sp, NormalizeDouble(StopLong(Bid, sl), Digits),
                          NormalizeDouble(TakeLong(Ask, tp), Digits), pComment,
                          pMagic, pDatetime, pColor);
        break;
      }
      break;
    case 3:
      for (c = 0; c < NumberOfTries; c++) {
        error = OrderSend(Symbol(), OP_SELLLIMIT, pLots, pLevel, sp,
                          StopShort(pr, sl), TakeShort(pLevel, tp), pComment,
                          pMagic, pDatetime, pColor);
        break;
      }
      break;
    case 5:
      for (c = 0; c < NumberOfTries; c++) {
        error = OrderSend(Symbol(), OP_SELLSTOP, pLots, pLevel, sp,
                          StopShort(pr, sl), TakeShort(pLevel, tp), pComment,
                          pMagic, pDatetime, pColor);
        break;
      }
      break;
    case 1:
      for (c = 0; c < NumberOfTries; c++) {
        error =
            OrderSend(Symbol(), OP_SELL, pLots, NormalizeDouble(Bid, Digits),
                      sp, NormalizeDouble(StopShort(Ask, sl), Digits),
                      NormalizeDouble(TakeShort(Bid, tp), Digits), pComment,
                      pMagic, pDatetime, pColor);
        break;
      }
  }
  return (error);
}

bool IsIndicatorHigh() {
  if (iRSI(NULL, 0, rsi_period, PRICE_TYPICAL, 0) < rsi_max &&
      iRSI(NULL, 0, rsi_period, PRICE_TYPICAL, 1) > rsi_max) {
    return true;
  }
  if (iStochastic(NULL, 0, stoch_period, 3, 3, MODE_SMA, 0, MODE_MAIN, 0) < stoch_max &&
      iStochastic(NULL, 0, stoch_period, 3, 3, MODE_SMA, 0, MODE_MAIN, 1) > stoch_max) {
   // return true;
    }

  return false;
}

bool IsIndicatorLow() {
  if (iRSI(NULL, 0, rsi_period, PRICE_TYPICAL, 0) > rsi_min &&
      iRSI(NULL, 0, rsi_period, PRICE_TYPICAL, 1) < rsi_min) {
    return true;
  }
  if (iStochastic(NULL, 0, stoch_period, 3, 3, MODE_SMA, 0, MODE_MAIN, 0) > stoch_min &&
      iStochastic(NULL, 0, stoch_period, 3, 3, MODE_SMA, 0, MODE_MAIN, 1) < stoch_min) {
   // return true;
  }
  return false;
}

/*
double  iStochastic(
   string       symbol,           // symbol
   int          timeframe,        // timeframe
   int          Kperiod,          // K line period
   int          Dperiod,          // D line period
   int          slowing,          // slowing
   int          method,           // averaging method
   int          price_field,      // price (Low/High or Close/Close)
   int          mode,             // line index
   int          shift             // shift
   );
 */