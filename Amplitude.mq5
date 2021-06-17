/*
Copyright (C) 2021 Mateus Matucuma Teixeira

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
*/
#ifndef AMPLITUDE_H
#define AMPLITUDE_H
//+------------------------------------------------------------------+
//|                                                    Amplitude.mq5 |
//|                         Copyright 2021, Mateus Matucuma Teixeira |
//|                                            mateusmtoss@gmail.com |
//| GNU General Public License version 2 - GPL-2.0                   |
//| https://opensource.org/licenses/gpl-2.0.php                      |
//+------------------------------------------------------------------+
// https://github.com/BRMateus2/Amplitude-Indicator/
//---- Main Properties
#property copyright "2021, Mateus Matucuma Teixeira"
#property link "https://github.com/BRMateus2/"
#property description "This Indicator will show the Amplitude [Minimum; Maximum] of a given period and can act as a substitute of the ATR indicator.\n"
#property description "The indicator can be used to observe volatility and the force of past swings, useful to determine excesses that will possibly be reversed or repeated, given that the user has knowledge to complement with volume or standard-deviation strategies.\n"
#property description "It is suggested a period of 55200 at M1 or 2400 at H1 (meaning 40 sessions of 23hs each), or any period that complements your strategy."
#property version "1.04"
#property strict
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots 1
#property indicator_label1 "Amplitude"
#property indicator_type1 DRAW_LINE
#property indicator_color1 clrTurquoise
#property indicator_style1 STYLE_SOLID
#property indicator_width1 1
// Metatrader 5 has a limitation of 64 User Input Variable description, for reference this has 64 traces ----------------------------------------------------------------
//---- Definitions
#define ErrorPrint(Dp_error) Print("ERROR: " + Dp_error + " at \"" + __FUNCTION__ + ":" + IntegerToString(__LINE__) + "\", last internal error: " + IntegerToString(GetLastError()) + " (" + __FILE__ + ")"); ResetLastError(); DebugBreak(); // It should be noted that the GetLastError() function doesn't zero the _LastError variable. Usually the ResetLastError() function is called before calling a function, after which an error appearance is checked.
//#define INPUT const
#ifndef INPUT
#define INPUT input
#endif
//---- Indicator Definitions
string short_name; // Defined at OnInit()
//---- Input Parameters
//---- "Basic Settings"
input group "Basic Settings"
INPUT int period_inp = 2400; // Amplitude of last N candles
int period = 60; // Backup period if user inserts wrong value
INPUT bool ignore_gaps_inp = false; // Ignore gaps between candles? (Not include last close?)
INPUT bool show_percentage = true; // Show percentage instead of absolute values? (V*100 / (H+L)/2)
//---- "Adaptive Period"
input group "Adaptive Period"
INPUT bool period_ad_inp = true; // Adapt the Period? Overrides Standard Period Settings
INPUT int period_ad_minutes_inp = 55200; // Period in minutes that all M and H timeframes should adapt to?
INPUT int period_ad_d1_inp = 40; // Period for D1 - Daily Timeframe
INPUT int period_ad_w1_inp = 8; // Period for W1 - Weekly Timeframe
INPUT int period_ad_mn1_inp = 2; // Period for MN - Monthly Timeframe
//---- Indicator Indexes, Buffers and Handlers
const int buf_i = 0;
double buf[];
//---- PlotIndexSetString() Timer optimization, updates once per second
datetime last = 0;
//+------------------------------------------------------------------+
//| Custom indicator initialization function
//+------------------------------------------------------------------+
int OnInit()
{
// User and Developer Input scrutiny
    if(period_ad_inp == true) { // Calculate period if period_adaptive_inp == true. Adaptation works flawless for less than D1 - D1, W1 and MN1 are a constant set by the user.
        if((PeriodSeconds(PERIOD_CURRENT) < PeriodSeconds(PERIOD_D1)) && (PeriodSeconds(PERIOD_CURRENT) >= PeriodSeconds(PERIOD_M1))) {
            if(period_ad_minutes_inp > 0) {
                int period_calc = ((period_ad_minutes_inp * 60) / PeriodSeconds(PERIOD_CURRENT));
                if(period_calc == 0) { // If the division is less than 1, then we have to complement to a minimum, user can also hide on timeframes that are not needed.
                    period = period_calc + 1;
                } else if(period < 0) {
                    ErrorPrint("calculation error with \"period = ((period_ad_minutes_inp * 60) / PeriodSeconds(PERIOD_CURRENT))\". Indicator will use value \"" + IntegerToString(period) + "\" for calculations."); // period is already defined
                } else { // If period_calc is not zero, neither negative, them it is valid.
                    period = period_calc;
                }
            } else {
                ErrorPrint("wrong value for \"period_ad_minutes_inp\" = \"" + IntegerToString(period_ad_minutes_inp) + "\". Indicator will use value \"" + IntegerToString(period) + "\" for calculations."); // period is already defined
            }
        } else if(PeriodSeconds(PERIOD_CURRENT) == PeriodSeconds(PERIOD_D1)) {
            if(period_ad_d1_inp > 0) {
                period = period_ad_d1_inp;
            } else {
                ErrorPrint("wrong value for \"period_ad_d1_inp\" = \"" + IntegerToString(period_ad_d1_inp) + "\". Indicator will use value \"" + IntegerToString(period) + "\" for calculations."); // period is already defined
            }
        } else if(PeriodSeconds(PERIOD_CURRENT) == PeriodSeconds(PERIOD_W1)) {
            if(period_ad_w1_inp > 0) {
                period = period_ad_w1_inp;
            } else {
                ErrorPrint("wrong value for \"period_ad_w1_inp\" = \"" + IntegerToString(period_ad_w1_inp) + "\". Indicator will use value \"" + IntegerToString(period) + "\" for calculations."); // period is already defined
            }
        } else if(PeriodSeconds(PERIOD_CURRENT) == PeriodSeconds(PERIOD_MN1)) {
            if(period_ad_mn1_inp > 0) {
                period = period_ad_mn1_inp;
            } else {
                ErrorPrint("wrong value for \"period_ad_mn1_inp\" = \"" + IntegerToString(period_ad_mn1_inp) + "\". Indicator will use value \"" + IntegerToString(period) + "\" for calculations."); // period is already defined
            }
        } else {
            ErrorPrint("untreated condition. Indicator will use value \"" + IntegerToString(period) + "\" for calculations."); // period is already defined
        }
    } else if(period_inp <= 0 && period_ad_inp == false) {
        ErrorPrint("wrong value for \"period_inp\" = \"" + IntegerToString(period_inp) + "\". Indicator will use value \"" + IntegerToString(period) + "\" for calculations."); // period is already defined
    } else {
        period = period_inp;
    }
// Treat Indicator
    if(!IndicatorSetInteger(INDICATOR_DIGITS, Digits())) { // Indicator subdigit precision
        ErrorPrint("IndicatorSetInteger(INDICATOR_DIGITS, Digits())");
        return INIT_FAILED;
    }
// Treat buf_i
    if(!SetIndexBuffer(buf_i, buf, INDICATOR_DATA)) { // Indicator Data visible to user
        ErrorPrint("SetIndexBuffer(buf_i, buf, INDICATOR_DATA)");
        return INIT_FAILED;
    };
    if(!PlotIndexSetInteger(buf_i, PLOT_DRAW_BEGIN, period)) { // Will begin after the period is satisfied (data will be hidden if less than period)
        ErrorPrint("PlotIndexSetInteger(buf_i, PLOT_DRAW_BEGIN, period)");
        return INIT_FAILED;
    }
// Subwindow Short Name
    short_name = StringFormat("A(%d)", period); // Indicator name in Subwindow
    if(!IndicatorSetString(INDICATOR_SHORTNAME, short_name)) { // Set Indicator name
        ErrorPrint("IndicatorSetString(INDICATOR_SHORTNAME, short_name)");
        return INIT_FAILED;
    }
    return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
//| Amplitude Calculation
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime& time[],
                const double& open[],
                const double& high[],
                const double& low[],
                const double& close[],
                const long& tick_volume[],
                const long& volume[],
                const int& spread[])
{
    if(rates_total < period) { // No need to calculate if the data is less than the requested period - it is returned as 0, because if we return rates_total, then the terminal interprets that the indicator has valid data
        return 0;
    }
    /*
        Math Function:
            On proposed Amplitude of a single candle, represents the MinMax of that candle, where:
                MinMax = Max - Min, if Max >= 0;
                MinMax = Min - Max, if Max < 0;
            For a period larger than 1, I propose the MinMax of the last X candles, where X equals to the period:
                MinMax = Highest Max - Lowest Min, where Highest and Lowest from the last X data points, if Max >= 0;
                MinMax = Lowest Min - Highest Max, where Highest and Lowest from the last X data points, if Max < 0;
            Since the first X candles are expected to be invalid, because there is no X < 0 data point, it will be skipped.

            If the setting Ignore Gaps is set, then the amplitude between last close candle and "current calculating candle" are not used, meaning the values are not absolutely-contiguous (in other words, gaps (auctions or broker gaps) are not meaningful at all when period is equal to 1).
    */
// Main loop of calculations
    int i = (prev_calculated - 1);
    for(; i < rates_total && !IsStopped(); i++) {
        if(i < 0) {
            continue;
        }
        double highest = DBL_MIN;
        double lowest = DBL_MAX;
        for(int j = (i - period + 1); j <= i && !IsStopped(); j++) {
            if(j < 0) {
                continue;
            }
            if(highest < (ignore_gaps_inp ? high[j] : (j == 0 ? high[j] : MathMax(high[j], close[j - 1])))) {
                highest = (ignore_gaps_inp ? high[j] : (j == 0 ? high[j] : MathMax(high[j], close[j - 1])));
            }
            if(lowest > (ignore_gaps_inp ? low[j] : (j == 0 ? low[j] : MathMin(low[j], close[j - 1])))) {
                lowest = (ignore_gaps_inp ? low[j] : (j == 0 ? low[j] : MathMin(low[j], close[j - 1])));
            }
        }
        buf[i] = show_percentage ? ((highest - lowest) * 100.0 / (MathAbs(highest + lowest) / 2.0)) : (highest - lowest);
    }
    if(i == rates_total && last < TimeCurrent()) {
        last = TimeCurrent();
        if(show_percentage) {
            PlotIndexSetString(buf_i, PLOT_LABEL, "Relative Amplitude (" + DoubleToString(buf[i - 1], 2) + "%)");
        } else {
            PlotIndexSetString(buf_i, PLOT_LABEL, "Absolute Amplitude (" + DoubleToString(buf[i - 1], Digits()) + ")");
        }
    }
    return rates_total; // Calculations are done and valid
}
//+------------------------------------------------------------------+
// Deinitialization
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    return;
}
//+------------------------------------------------------------------+
//| Header Guard #endif
//+------------------------------------------------------------------+
#endif
//+------------------------------------------------------------------+
