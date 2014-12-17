-module(ws_handler).

-export([init/2]).
-export([websocket_handle/3]).
-export([websocket_info/3]).

init(Req, Opts) ->
    %erlang:start_timer(1000, self(), <<"Hello!">>),
	{cowboy_websocket, Req, Opts}.

websocket_handle({text, Msg}, Req, State) ->
    Result = message:decode(Msg),
    lager:info("Result: ~p", [Result]),

	{reply, {text, Result}, Req, State};

websocket_handle(_Data, Req, State) ->
	{ok, Req, State}.

websocket_info({new_perception, Message}, Req, State) ->
    Encoded = jsx:encode([Message]),

	{reply, {text, Encoded}, Req, State};
websocket_info(_Info, Req, State) ->
	{ok, Req, State}.