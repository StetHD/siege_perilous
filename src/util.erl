%% Author: Peter
%% Created: Dec 24, 2008
%% Description: TODO: Add description to util
-module(util).

%%
%% Include files
%%

-include("common.hrl").
-include("schema.hrl").

%%
%% Exported Functions
%%
-export([rand/0, rand/1,
         round3/1,
         ceiling/1,
         floor/1,
         diff_game_days/2,
         get_time/0,
         get_time_seconds/0,
         unique_list/1,
         replace/3,
         is_process_alive/1,
         get_app/1,
         bin_to_hex/1,
         hex_to_bin/1,
         console_on/0,
         console_off/0,
         debug/1,
         capfirst/1,
         get_id/0
        ]).

%%
%% API Functions
%%
rand() -> rand:uniform().
rand(0) -> 0;
rand(Num) -> rand:uniform(Num).

round3(Num) ->
    RoundedNum = round(Num * 1000),
    RoundedNum / 1000.    

ceiling(X) ->
    T = erlang:trunc(X),
    case (X - T) of
        Neg when Neg < 0 -> T;
        Pos when Pos > 0 -> T + 1;
        _ -> T
    end.

floor(X) ->
    T = erlang:trunc(X),
    case (X - T) of
        Neg when Neg < 0 -> T - 1;
        Pos when Pos > 0 -> T;
        _ -> T
    end.

unique_list(L) ->
    Set = sets:from_list(L),
    sets:to_list(Set).

replace(1, [_|Rest], New) -> [New|Rest];
replace(I, [E|Rest], New) -> [E|replace(I-1, Rest, New)].

is_process_alive(Pid) 
  when is_pid(Pid) ->
    rpc:call(node(Pid), erlang, is_process_alive, [Pid]).

get_time() ->
    {Megasec, Sec, Microsec} = erlang:now(),
    Milliseconds = (Megasec * 1000000000) + (Sec * 1000) + (Microsec div 1000),
    Milliseconds.

get_time_seconds() ->
    {Megasec, Sec, _Microsec} = erlang:now(),
    Seconds = (Megasec * 1000000) + Sec,
    Seconds.

diff_game_days(StartTime, EndTime) ->
    Diff = EndTime - StartTime,
    NumGameDays = Diff / (3600 * ?GAME_NUM_HOURS_PER_DAY),
    NumGameDays.

get_app(Module) ->
    {ok, App} = application:get_application(Module),
    App.

bin_to_hex(BsonId) when is_tuple(BsonId) ->
    {Bin} = BsonId,
    bin_to_hex(Bin);
bin_to_hex(Bin) -> 
    list_to_binary([ hd(integer_to_list(I, 16)) || << I:4 >> <= Bin ]).

hex_to_bin(BinStr) when is_binary(BinStr) ->
    hex_to_bin(binary_to_list(BinStr));
hex_to_bin(Str) -> 
    {<< << (list_to_integer([H], 16)):4 >> || H <- Str >>}.

console_off() ->
    lager:set_loglevel(lager_console_backend, none).
console_on() ->
    lager:set_loglevel(lager_console_backend, info).

debug(true) -> lager:set_loglevel(lager_console_backend, debug);
debug(false) -> lager:set_loglevel(lager_console_backend, info).

capfirst([Head | Tail]) when Head >= $a, Head =< $z ->
    [Head + ($A - $a) | Tail];
capfirst(Other) ->
    Other.

get_id() ->
    Time = bson:timenow(),
    bson:objectid(bson:unixtime_to_secs(Time), <<2:24/big, 3:16/big>>, counter:increment(id)).
