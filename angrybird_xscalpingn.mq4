// extern double trail_stop = 10.0;
bool dynamic_pips = TRUE; /* Should be comments for these */
bool flag = FALSE;
bool long_trade = FALSE;
bool NewOrdersPlaced = FALSE;
bool ShortTrade = FALSE;
bool TradeNow = FALSE;
bool UseEquityStop = FALSE;
bool use_timeout = FALSE;
bool UseTrailingStop = FALSE;
double AccntEquityHighAmt = 0;
double AveragePrice = 0;
double BuyLimit = 0;
double BuyTarget = 0;
double iLots = 0;
double LastBuyPrice = 0;
double LastSellPrice = 0;
double MaxTradeOpenHours = 48.0;
double PrevEquity = 0;
double PriceTarget = 0;
double SellLimit = 0;
double SellTarget = 0;
double slip = 3.0;
double Spread = 0;
double StartEquity = 0;
double Stoploss = 500.0;
double Stopper = 0.0;
double TotalEquityRisk = 20.0;
double TrailStart = 10.0;
extern double lot_exponent = 2.0;
extern double lots = 0.01;
extern double i_maximum = 90.0;
extern double i_minimum = 10.0;
extern int i_period = 14;
int i_timeout = 3;
extern double take_profit = 1200.0;
int max_trades = 100;
int min_pip_height = 10;
int pip_divisor = 1;
int pip_memory = 6;
int MagicNumber = 2222;
int cnt = 0;
int expiration = 0;
int lotdecimal = 2;
int NumOfTrades = 0;
int PipStep = 10;
int ticket = 0;
int timeprev = 0;
int total = 0;
string EAName = "Ilan1.6";

int init() {
  Spread = MarketInfo(Symbol(), MODE_SPREAD) * Point;
  return (0);
}

int deinit() { return (0); }

void DynamicPips() {
    // Calculate highest and lowest price from last bar to X bars ago
    double hival = High[iHighest(NULL, 0, MODE_HIGH, pip_memory, 1)];
    double loval = Low[iLowest(NULL, 0, MODE_LOW, pip_memory, 1)];

    // Calculate pips for spread between orders
    PipStep = NormalizeDouble((hival - loval) / pip_divisor / Point, 0);

    // If dynamic pips fail, assign pips extreme value
    if (PipStep < min_pip_height) {
      PipStep = NormalizeDouble(min_pip_height, 0);
    }

    // if (PipStep > min_pip_height * pip_divisor) {
    //  PipStep = NormalizeDouble(min_pip_height * pip_divisor, 0);
    //}
}

int start() {
  //DynamicPips();
  Comment(PipStep);

  // Trailing stop
  if (UseTrailingStop) {
    // TrailingAlls(TrailStart, trail_stop, AveragePrice);
  }

  // Timeout
  if (use_timeout)
  {
    if  ((iStochastic(NULL, 0, (i_period * i_timeout), 3, 3, MODE_SMA, 0, MODE_MAIN, 0) < 2 && ShortTrade) ||
         (iStochastic(NULL, 0, (i_period * i_timeout), 3, 3, MODE_SMA, 0, MODE_MAIN, 0) > 98 && long_trade)) /* long = buy */
    {
      CloseThisSymbolAll();
      Print("Closed All due to TimeOut");
    }
  }

  if (timeprev == Time[0]) {
    return (0);
  }
  timeprev = Time[0];

  // Equitiy stop
  double CurrentPairProfit = CalculateProfit();
  if (UseEquityStop) {
    if (CurrentPairProfit < 0.0 &&
        MathAbs(CurrentPairProfit) >
            TotalEquityRisk / 100.0 * AccountEquityHigh()) {
      CloseThisSymbolAll();
      Print("Closed All due to Stop Out");
      NewOrdersPlaced = FALSE;
    }
  }

  // Trades
  total = CountTrades();
  if (total == 0) flag = FALSE;

  for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
    if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) {
      CheckError();
    };
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
      continue;
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
      if (OrderType() == OP_BUY) {
        long_trade = TRUE;
        ShortTrade = FALSE;
        break;
      }
    }
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
      if (OrderType() == OP_SELL) {
        long_trade = FALSE;
        ShortTrade = TRUE;
        break;
      }
    }
  }

  if (total > 0 && total <= max_trades) {
    RefreshRates();
    LastBuyPrice = FindLastBuyPrice();
    LastSellPrice = FindLastSellPrice();
    //if (long_trade && LastBuyPrice - Ask >= PipStep * Point) TradeNow = TRUE;
    //if (ShortTrade && Bid - LastSellPrice >= PipStep * Point) TradeNow = TRUE;
    
    /* Short = sell */
    
    if (ShortTrade && Bid > LastSellPrice) {
      if (iStochastic(NULL, 0, i_period, 3, 3, MODE_SMA, 0, MODE_MAIN, 0) >= i_maximum &&
          iStochastic(NULL, 0, i_period, 3, 3, MODE_SMA, 0, MODE_MAIN, 1) <= i_maximum) {
            TradeNow = TRUE;
          } else {
            TradeNow = FALSE;
          }
    }
    else if (long_trade && Ask < LastBuyPrice) {
      if (iStochastic(NULL, 0, i_period, 3, 3, MODE_SMA, 0, MODE_MAIN, 0) <= i_minimum &&
          iStochastic(NULL, 0, i_period, 3, 3, MODE_SMA, 0, MODE_MAIN, 1) >= i_minimum) {
            TradeNow = TRUE;
          } else {
            TradeNow = FALSE;
          }
    }
  }

  if (total < 1) {
    ShortTrade = FALSE;
    long_trade = FALSE;
    TradeNow = TRUE;
    StartEquity = AccountEquity();
  }

  if (TradeNow) {
    LastBuyPrice = FindLastBuyPrice();
    LastSellPrice = FindLastSellPrice();

    if (ShortTrade) {
      NumOfTrades = total;
      iLots = GetLots();
      RefreshRates();
      ticket = OpenPendingOrder(1, iLots, Bid, slip, Ask, 0, 0,
                                EAName + "-" + NumOfTrades + "-" + PipStep,
                                MagicNumber, 0, HotPink);
      Print(CountTrades());
      LastSellPrice = FindLastSellPrice();
      TradeNow = FALSE;
      NewOrdersPlaced = TRUE;

    } else {
      if (long_trade) {
        NumOfTrades = total;
        iLots = GetLots();
        ticket = OpenPendingOrder(0, iLots, Ask, slip, Bid, 0, 0,
                                  EAName + "-" + NumOfTrades + "-" + PipStep,
                                  MagicNumber, 0, Lime);
        LastBuyPrice = FindLastBuyPrice();
        TradeNow = FALSE;
        NewOrdersPlaced = TRUE;
      }
    }

    if (ticket < 0) {
      CheckError();
      return (-1);
    }
  }

  if (TradeNow && total < 1) {
    // double PrevCl = iClose(Symbol(), 0, 2);
    // double CurrCl = iClose(Symbol(), 0, 1);
    SellLimit = Bid;
    BuyLimit = Ask;

    if (!ShortTrade && !long_trade) {
      // if (iRSI(NULL, 0, i_period, PRICE_TYPICAL, 1) > i_maximum) {
      if (iStochastic(NULL, 0, i_period, 3, 3, MODE_SMA, 0, MODE_MAIN, 0) > i_maximum
     // && iStochastic(NULL, 0, i_period, 3, 3, MODE_SMA, 0, MODE_MAIN, 1) < i_maximum
     )
      {
        NumOfTrades = total;
        iLots = GetLots();
        ticket = OpenPendingOrder(1, iLots, SellLimit, slip, SellLimit, 0, 0,
                                  EAName + "-" + NumOfTrades, MagicNumber, 0,
                                  HotPink);

        LastBuyPrice = FindLastBuyPrice();
        NewOrdersPlaced = TRUE;
        TradeNow = FALSE;

      } else if (iStochastic(NULL, 0, i_period, 3, 3, MODE_SMA, 0, MODE_MAIN, 0) < i_minimum
              // && iStochastic(NULL, 0, i_period, 3, 3, MODE_SMA, 0, MODE_MAIN, 1) > i_minimum
              )
              {
      // else if (iRSI(NULL, 0, i_period, PRICE_TYPICAL, 1) < i_minimum) {
        NumOfTrades = total;
        iLots = GetLots();

        ticket =
            OpenPendingOrder(0, iLots, BuyLimit, slip, BuyLimit, 0, 0,
                             EAName + "-" + NumOfTrades, MagicNumber, 0, Lime);

        LastSellPrice = FindLastSellPrice();
        NewOrdersPlaced = TRUE;
        TradeNow = FALSE;
      }

      if (ticket < 0) {
        CheckError();
        return (0);
      } else {
        expiration = TimeCurrent() + 60.0 * (60.0 * MaxTradeOpenHours);
      }
    }
  }

  total = CountTrades();
  AveragePrice = 0;
  double Count = 0;

  for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
    if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) {
      CheckError();
    }
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
      continue;
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
      if (OrderType() == OP_BUY || OrderType() == OP_SELL) {
        // AveragePrice += ((OrderClosePrice() + OrderClosePrice() +
        // OrderOpenPrice()) / 3) * OrderLots();
        // AveragePrice += ((OrderClosePrice() + OrderOpenPrice() +
        // OrderOpenPrice()) / 3) * OrderLots();
        // AveragePrice += ((OrderClosePrice() + OrderOpenPrice()) / 2) *
        // OrderLots();
        // AveragePrice += OrderClosePrice() * OrderLots();
        AveragePrice += OrderOpenPrice() * OrderLots();
        Count += OrderLots();
      }
    }
  }

  if (total > 0) AveragePrice = NormalizeDouble(AveragePrice / Count, Digits);

  if (NewOrdersPlaced) {
    for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
      if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) {
        CheckError();
      }
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
        continue;
      if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
        if (OrderType() == OP_BUY) {
          PriceTarget = AveragePrice + take_profit * Point;
          BuyTarget = PriceTarget;
          Stopper = AveragePrice - Stoploss * Point;
          flag = TRUE;
        }
      }
      if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
        if (OrderType() == OP_SELL) {
          PriceTarget = AveragePrice - take_profit * Point;
          SellTarget = PriceTarget;
          Stopper = AveragePrice + Stoploss * Point;
          flag = TRUE;
        }
      }
    }
  }

  if (NewOrdersPlaced) {
    if (flag) {
      for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
        if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) {
          CheckError();
        }
        if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
          continue;
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
          if (!OrderModify(OrderTicket(), NormalizeDouble(AveragePrice, Digits),
                           NormalizeDouble(OrderStopLoss(), Digits),
                           NormalizeDouble(PriceTarget, Digits), 0, Yellow)) {
            CheckError();
          }
        }
        NewOrdersPlaced = FALSE;
      }
    }
  }

  /* End loop */
  return (0);
}

/*Helper functions*/
int CountTrades() {
  int count = 0;
  for (int trade = OrdersTotal() - 1; trade >= 0; trade--) {
    if (!OrderSelect(trade, SELECT_BY_POS, MODE_TRADES)) {
      CheckError();
    }
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
      continue;
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
      if (OrderType() == OP_SELL || OrderType() == OP_BUY) count++;
  }
  return (count);
}

void CloseThisSymbolAll() {
  for (int trade = OrdersTotal() - 1; trade >= 0; trade--) {
    if (!OrderSelect(trade, SELECT_BY_POS, MODE_TRADES)) {
      CheckError();
    }
    if (OrderSymbol() == Symbol()) {
      if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
        if (OrderType() == OP_BUY)
          if (!OrderClose(OrderTicket(), OrderLots(), Bid, slip, Blue)) {
            CheckError();
          }
        if (OrderType() == OP_SELL)
          if (!OrderClose(OrderTicket(), OrderLots(), Ask, slip, Red)) {
            CheckError();
          }
      }
      Sleep(1000);
    }
  }
}

int OpenPendingOrder(int pType, double pLots, double pLevel, int sp, double pr,
                     int sl, int tp, string pComment, int pMagic, int pDatetime,
                     color pColor) {
  int c = 0;
  int NumberOfTries = 100;
  switch (pType) {
    case 2:
      for (c = 0; c < NumberOfTries; c++) {
        ticket = OrderSend(Symbol(), OP_BUYLIMIT, pLots, pLevel, sp,
                           StopLong(pr, sl), TakeLong(pLevel, tp), pComment,
                           pMagic, pDatetime, pColor);
        if (!CheckError()) break;
      }
      break;
    case 4:
      for (c = 0; c < NumberOfTries; c++) {
        ticket = OrderSend(Symbol(), OP_BUYSTOP, pLots, pLevel, sp,
                           StopLong(pr, sl), TakeLong(pLevel, tp), pComment,
                           pMagic, pDatetime, pColor);
        if (!CheckError()) break;
      }
      break;
    case 0:
      for (c = 0; c < NumberOfTries; c++) {
        RefreshRates();
        ticket =
            OrderSend(Symbol(), OP_BUY, pLots, NormalizeDouble(Ask, Digits), sp,
                      NormalizeDouble(StopLong(Bid, sl), Digits),
                      NormalizeDouble(TakeLong(Ask, tp), Digits), pComment,
                      pMagic, pDatetime, pColor);
        if (!CheckError()) break;
      }
      break;
    case 3:
      for (c = 0; c < NumberOfTries; c++) {
        ticket = OrderSend(Symbol(), OP_SELLLIMIT, pLots, pLevel, sp,
                           StopShort(pr, sl), TakeShort(pLevel, tp), pComment,
                           pMagic, pDatetime, pColor);
        if (!CheckError()) break;
      }
      break;
    case 5:
      for (c = 0; c < NumberOfTries; c++) {
        ticket = OrderSend(Symbol(), OP_SELLSTOP, pLots, pLevel, sp,
                           StopShort(pr, sl), TakeShort(pLevel, tp), pComment,
                           pMagic, pDatetime, pColor);
        if (!CheckError()) break;
      }
      break;
    case 1:
      for (c = 0; c < NumberOfTries; c++) {
        ticket =
            OrderSend(Symbol(), OP_SELL, pLots, NormalizeDouble(Bid, Digits),
                      sp, NormalizeDouble(StopShort(Ask, sl), Digits),
                      NormalizeDouble(TakeShort(Bid, tp), Digits), pComment,
                      pMagic, pDatetime, pColor);
        if (!CheckError()) break;
      }
  }
  return (ticket);
}

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

double CalculateProfit() {
  double Profit = 0;
  for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
    if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) {
      CheckError();
    }
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
      continue;
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
      if (OrderType() == OP_BUY || OrderType() == OP_SELL)
        Profit += OrderProfit();
  }
  return (Profit);
}

void TrailingAlls(int pType, int stop, double AvgPrice) {
  if (stop != 0) {
    for (int trade = OrdersTotal() - 1; trade >= 0; trade--) {
      if (OrderSelect(trade, SELECT_BY_POS, MODE_TRADES)) {
        if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
          continue;
        if (OrderSymbol() == Symbol() || OrderMagicNumber() == MagicNumber) {
          if (OrderType() == OP_BUY) {
            double stoptrade = 0;
            double stopcal = 0;
            int profit = 0;
            profit = NormalizeDouble((Bid - AvgPrice) / Point, 0);
            if (profit < pType) continue;
            stoptrade = OrderStopLoss();
            stopcal = Bid - stop * Point;
            if (stoptrade == 0.0 || (stopcal > stoptrade)) {
              if (!OrderModify(OrderTicket(), AvgPrice, stopcal,
                               OrderTakeProfit(), 0, Aqua)) {
                CheckError();
              }
            }
          }
          if (OrderType() == OP_SELL) {
            profit = NormalizeDouble((AvgPrice - Ask) / Point, 0);
            if (profit < pType) continue;
            stoptrade = OrderStopLoss();
            stopcal = Ask + stop * Point;
            if (stoptrade == 0.0 || (stopcal < stoptrade)) {
              if (!OrderModify(OrderTicket(), AvgPrice, stopcal,
                               OrderTakeProfit(), 0, Red)) {
                CheckError();
              }
            }
          }
        }
        Sleep(1000);
      }
    }
  }
}

double AccountEquityHigh() {
  if (CountTrades() == 0) AccntEquityHighAmt = AccountEquity();
  if (AccntEquityHighAmt < PrevEquity)
    AccntEquityHighAmt = PrevEquity;
  else
    AccntEquityHighAmt = AccountEquity();
  PrevEquity = AccountEquity();

  return (AccntEquityHighAmt);
}

double FindLastBuyPrice() {
  double oldorderopenprice;
  int oldticketnumber;
  int ticketnumber = 0;
  for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
    if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) {
      CheckError();
    }
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
      continue;
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber &&
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
  for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
    if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) {
      CheckError();
    }
    if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
      continue;
    if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber &&
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

bool CheckError() {
  int err = GetLastError();
  if (err) Print("Error: " + err);
  return (err == 4 /* SERVER_BUSY */ || err == 137 /* BROKER_BUSY */
          || err == 146 /* TRADE_CONTEXT_BUSY */ ||
          err == 136 /* OFF_QUOTES */);
}

double GetLots() {
  return NormalizeDouble(lots * MathPow(lot_exponent, NumOfTrades),
                              lotdecimal);
}
