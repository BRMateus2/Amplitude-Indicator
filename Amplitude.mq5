/*
Copyright (C) 2021 Mateus Matucuma Teixeira

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
*/
#ifndef A_H
#define A_H
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
#property description "The indicator can be used to observe volatility and the force of past swings, useful to determine excess movements that will possibly be reversed or repeated, given that the user has knowledge to complement with volume flux or standard-deviation strategies.\n"
#property description "It is suggested a period of 23 at 1H (meaning 1 session), for 24hs markets, or any period that complements your strategy."
#property version "1.01"
#property strict
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots 1
#property indicator_type1 DRAW_LINE
#property indicator_color1 clrTurquoise
#property indicator_label1 "Amplitude"
// Metatrader 5 has a limitation of 64 User Input Variable description, for reference this has 64 traces ----------------------------------------------------------------
//---- Definitions
#define ErrorPrint(error) Print("ERROR: " + error + " at \"" + __FUNCTION__ + ":" + IntegerToString(__LINE__) + "\", last internal error: " + IntegerToString(GetLastError()) + " (" + __FILE__ + ")"); ResetLastError(); DebugBreak(); // It should be noted that the GetLastError() function doesn't zero the _LastError variable. Usually the ResetLastError() function is called before calling a function, after which an error appearance is checked.
//#define _INPUT const
#ifndef _INPUT
#define _INPUT input
#endif
//---- Indicator Definitions
string short_name; // Defined at OnInit()
//---- Input Parameters
//---- "Basic Settings"
input group "Basic Settings"
_INPUT int a_period_inp = 23; // Amplitude of last N candles
int a_period = 1; // Backup period if user inserts wrong value
_INPUT bool a_ignore_gaps = false; // Ignore gaps between candles? (Not include last close?)
//_INPUT bool a_use_percentage = true; // Show data as percentage points? TODO
//---- "Adaptive Period"
input group "Adaptive Period (overrides Basic Period Settings)"
_INPUT bool period_adaptive = true; // Adapt the Period to attempt to match a given higher setting?
_INPUT int period_adaptive_minutes = 1380; // Period in minutes that all timeframes should adapt to?
//---- Indicator Buffers
double a_buffer[] = {};
//+------------------------------------------------------------------+
//| Custom indicator initialization function
//+------------------------------------------------------------------+
int OnInit()
{
// User and Developer Input scrutiny
    if(period_adaptive == true) { // Calculate a_period if period_adaptive == true. The problem with this simple method, is that D1, W1 and MN are all set wrong and the user should correct by himself. The only way to automatically correct this is by forcing a "double period_days = variable", counting how many bars there are in a single day and multiplying, resulting in a adaptive period factor.
        if(period_adaptive_minutes > 0) {
            a_period = ((period_adaptive_minutes * 60) / PeriodSeconds(PERIOD_CURRENT));
            if(a_period == 0) { // If the division is less than 1, then we have to complement to a minimum, user can also hide on timeframes that are not needed.
                a_period = a_period + 1;
            } else if(a_period < 0) {
                ErrorPrint("calculation error with \"a_period = ((period_adaptive_minutes * 60) / PeriodSeconds(PERIOD_CURRENT))\"");
            }
        } else {
            ErrorPrint("wrong value for \"period_adaptive_minutes\" = \"" + IntegerToString(period_adaptive_minutes) + "\". Indicator will use value \"" + IntegerToString(a_period) + "\" for calculations."); // a_period is already defined
        }
    } else if(a_period_inp <= 0 && period_adaptive == false) {
        ErrorPrint("wrong value for \"a_period_inp\" = \"" + IntegerToString(a_period_inp) + "\". Indicator will use value \"" + IntegerToString(a_period) + "\" for calculations."); // a_period is already defined
    } else {
        a_period = a_period_inp;
    }
    if(!IndicatorSetInteger(INDICATOR_DIGITS, Digits())) { // Indicator subdigit precision
        ErrorPrint("IndicatorSetInteger(INDICATOR_DIGITS, Digits())");
        return INIT_FAILED;
    }
    if(!SetIndexBuffer(0, a_buffer, INDICATOR_DATA)) { // Indicator Data visible to user, Index 0
        ErrorPrint("SetIndexBuffer(0, a_buffer, INDICATOR_DATA)");
        return INIT_FAILED;
    };
    if(!PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, a_period)) { // Index 0 will begin after the period is satisfied (data will be hidden if less than a_period)
        ErrorPrint("PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, a_period)");
        return INIT_FAILED;
    }
    short_name = StringFormat("Amplitude(%d)", a_period); // Indicator name in Subwindow
    if(!IndicatorSetString(INDICATOR_SHORTNAME, short_name)) { // Set Indicator name
        ErrorPrint("IndicatorSetString(INDICATOR_SHORTNAME, short_name)");
        return INIT_FAILED;
    }
    if(!PlotIndexSetString(0, PLOT_LABEL, "Absolute Amplitude")) { // Set Index 0 description to user
        ErrorPrint("PlotIndexSetString(0, PLOT_LABEL, \"Absolute Amplitude\")");
        return INIT_FAILED;
    }
    return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
//| Amplitude Calculation
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    if(rates_total <= a_period) { // No need to calculate if the data is less than the requested period
        return 0;
    }
    /*
        Math Function:
            On proposed Relative Amplitude of a single candle, represents the MinMax of that candle, where:
                MinMax = Max - Min, if Max >= 0;
                MinMax = Min - Max, if Max < 0;
            For a period larger than 1, I propose the MinMax of the last X candles, where X equals to the period:
                MinMax = Highest Max - Lowest Min, where Highest and Lowest from the last X data points, if Max >= 0;
                MinMax = Lowest Min - Highest Max, where Highest and Lowest from the last X data points, if Max < 0;
            Since the first X candles are expected to be invalid, because there is no X < 0 data point, it will be nullified with 0.0.

            If the setting Ignore Gaps is set, then the amplitude between last close candle and "current calculating candle" are not used, meaning the values are not absolutely-contiguous (in other words, gaps (auctions or broker gaps) are not meaningful at all when period is equal to 1).
    */
// Main loop of calculations
    int i, j;
    double highest, lowest;
    for(i = (prev_calculated - 1); i < rates_total && !IsStopped(); i++) {
        if(i < 0) {
            continue;
        }
        highest = DBL_MIN;
        lowest = DBL_MAX;
        for(j = (i - a_period + 1); j <= i; j++) {
            if(j < 0) {
                continue;
            }
            if(highest < (a_ignore_gaps ? high[j] : (j == 0 ? high[j] : MathMax(high[j], close[j - 1])))) {
                highest = (a_ignore_gaps ? high[j] : (j == 0 ? high[j] : MathMax(high[j], close[j - 1])));
            }
            if(lowest > (a_ignore_gaps ? low[j] : (j == 0 ? low[j] : MathMin(low[j], close[j - 1])))) {
                lowest = (a_ignore_gaps ? low[j] : (j == 0 ? low[j] : MathMin(low[j], close[j - 1])));
            }
        }
        if(highest >= 0) {
            a_buffer[i] = highest - lowest;
        } else {
            a_buffer[i] = MathAbs(lowest - highest);
        }
    }
    return rates_total;
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
