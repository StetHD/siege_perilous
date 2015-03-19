%% -------------------------------------------------------------------
%% Author  : Peter Holko
%%% Description : NPC server
%%%
%%% Created : Jan 5, 2015
%%% -------------------------------------------------------------------
-module(npc).

-behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("schema.hrl").
-include("common.hrl").
%% --------------------------------------------------------------------
%% External exports
-export([start/1, init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% ====================================================================
%% External functions
%% ====================================================================

start(PlayerId) ->
    gen_server:start({global, {npc, PlayerId}}, npc, [PlayerId], []).

%% ====================================================================
%% Server functions
%% ====================================================================

init([PlayerId]) ->
    %Store player id in process dict
    put(player_id, PlayerId),

    %Store npc process in connection table
    [Connection] = db:dirty_read(connection, PlayerId),
    NewConnection = Connection#connection {process = self()},
    db:dirty_write(NewConnection),

    {ok, []}.

handle_cast(create, Data) ->   

    {noreply, Data};

handle_cast(stop, Data) ->
    {stop, normal, Data}.

handle_call(Event, From, Data) ->
    error_logger:info_report([{module, ?MODULE}, 
                              {line, ?LINE},
                              {self, self()}, 
                              {message, Event}, 
                              {from, From}
                             ]),
    {noreply, Data}.

handle_info({map_perception_disabled, Perception}, Data) ->
    lager:info("Map perception: ~p", [Perception]),

    {_Explored, Objs} = new_perception(Perception),
    {NPCObjs, EnemyObjs} = split_objs(Objs, [], []),
    process_action(NPCObjs, EnemyObjs),

    {noreply, Data};

handle_info({local_perception, Perception}, Data) ->
    lager:info("Local perception: ~p", [Perception]),
    
    {_Explored, Objs} = new_perception(Perception),
    {NPCObjs, EnemyObjs} = split_objs(Objs, [], []),

    F = fun(NPCObj) ->
            process_local_action(NPCObj, EnemyObjs)
    end,

    lists:foreach(F, NPCObjs),

    {noreply, Data};

handle_info(Info, Data) ->
    error_logger:info_report([{module, ?MODULE}, 
                              {line, ?LINE},
                              {self, self()}, 
                              {message, Info}]),
    {noreply, Data}.

code_change(_OldVsn, Data, _Extra) ->
    {ok, Data}.

terminate(_Reason, _) ->
    ok.

%% --------------------------------------------------------------------
%%% Internal functions
%% --------------------------------------------------------------------

new_perception([{<<"explored">>, Explored}, {<<"objs">>, Objs}]) ->
    {Explored, Objs}.

split_objs([], NPCObjs, EnemyObjs) ->
    {NPCObjs, EnemyObjs};
split_objs([Obj | Rest], NPCObjs, EnemyObjs) ->

    Player = get(player_id),
    ObjPlayer = maps:get(<<"player">>, Obj),
    ComparePlayer = Player =:= ObjPlayer,

    {NewNPCObjs, NewEnemyObjs} = add_npc_obj(Obj, NPCObjs, EnemyObjs, ComparePlayer),

    split_objs(Rest, NewNPCObjs, NewEnemyObjs).

add_npc_obj(Obj, NPCObjs, EnemyObjs, true) ->
    {[Obj | NPCObjs], EnemyObjs};
add_npc_obj(Obj, NPCObjs, EnemyObjs, false) ->
    {NPCObjs, [Obj | EnemyObjs]}.

process_action(NPCObjs, EnemyObjs) ->
    %Do nothing for now for explored

    F = fun(NPCObj) ->
            Action = none,
            NewAction = check_objs(NPCObj, EnemyObjs, Action),
            add_action(NewAction)
        end,

    lists:foreach(F, NPCObjs).

check_objs(_NPCObjs, [], Action) ->
    Action;

check_objs(NPCObj, [EnemyObj | Rest], Action) ->

    NPCId = maps:get(<<"id">>, NPCObj),
    NPCX = maps:get(<<"x">>, NPCObj),
    NPCY = maps:get(<<"y">>, NPCObj),
    NPCState = maps:get(<<"state">>, NPCObj),
    NPCPos = {NPCX, NPCY},

    Id = maps:get(<<"id">>, EnemyObj),
    X = maps:get(<<"x">>, EnemyObj),
    Y = maps:get(<<"y">>, EnemyObj),
    State = maps:get(<<"state">>, EnemyObj),
    Pos = {X, Y},

    CheckPos = NPCPos =:= Pos, 
 
    lager:info("Action: ~p CheckPos: ~p NPC: ~p Enemy: ~p", [Action, CheckPos, {NPCId, NPCPos, NPCState}, {Id, Pos, State}]),
    NewAction = determine_action(Action, 
                                 CheckPos,
                                 {NPCId, NPCPos, NPCState},
                                 {Id, Pos, State}),
    lager:info("NewAction: ~p", [NewAction]),
    check_objs(NPCObj, Rest, NewAction).

determine_action(_Action, false, {NPCId, _NPCPos, none}, {_Id, Pos, none}) ->
    lager:info("determine_action move npcid: ~p pos: ~p", [NPCId, Pos]),
    {move, {NPCId, Pos}};
determine_action(_Action, true, {NPCId, _NPCPos, none}, {Id, _Pos, none}) ->
    lager:info("determine_action attack npcid: ~p id: ~p", [NPCId, Id]),
    {attack, {NPCId, Id}};
determine_action(_Action, _Pos, NPC, _Enemy) ->
    {none, {NPC}}.

add_action({move, {NPCId, Pos}}) ->
    lager:info("npc ~p adding move", [NPCId]),
    Obj = obj:get_map_obj(NPCId),
    NumTicks = 8,
    
    obj:update_state(NPCId, move),

    %Create event data 
    EventData = {Obj#obj.player,
                 Obj#obj.id,
                 Pos},
    
    game:add_event(self(), move_obj, EventData, NumTicks);

add_action({attack, {NPCId, Id}}) ->
    lager:info("npc adding attack"),

    NumTicks = 8,
    EventData = {NPCId, Id},

    obj:update_state(NPCId, attack),
 
    game:add_event(self(), attack_obj, EventData, NumTicks);

add_action({none, _Data}) ->
    lager:info("NPC doing nothing");

add_action(none) ->
    lager:info("NPC doing nothing").

process_local_action(NPCUnit, EnemyUnits) ->
    NPCPos = get_pos(NPCUnit),
    EnemyUnit = get_nearest(NPCPos, EnemyUnits, {none, 1000}),
    EnemyPos = get_pos(EnemyUnit),
    
    Path = astar:astar(NPCPos, EnemyPos),
    lager:info("Path: ~p", [Path]),
    NextAction = next_action(NPCUnit, EnemyUnit, Path),

    add_battle_action(NextAction). 

get_nearest(_NPCUnit, [], {EnemyUnit, _Distance}) ->
    EnemyUnit;
get_nearest(NPCPos, [NewEnemyUnit | EnemyUnits], {EnemyUnit, Distance}) ->
    NewEnemyUnitPos = {maps:get(<<"x">>, NewEnemyUnit), maps:get(<<"y">>, NewEnemyUnit)},

    {TargetEnemyUnit, NewDistance} = compare_distance(map:distance(NPCPos, NewEnemyUnitPos), 
                                                      Distance,
                                                      NewEnemyUnit,
                                                      EnemyUnit),

    get_nearest(NPCPos, EnemyUnits, {TargetEnemyUnit, NewDistance}).
        
compare_distance(NewDistance, Distance, _New, Old) when NewDistance >= Distance ->
    {Old, Distance};
compare_distance(NewDistance, Distance, New, _Old) when NewDistance < Distance ->
    {New, NewDistance}.

next_action(NPCUnit, _EnemyUnit, Path) when length(Path) > 2 ->
    {move, NPCUnit, lists:nth(2,Path)};
next_action(NPCUnit, EnemyUnit, Path) when length(Path) =< 2 ->
    {attack, NPCUnit, EnemyUnit}.

add_battle_action({attack, SourceId, TargetId}) ->
    battle:attack_unit(SourceId, TargetId);
add_battle_action({move, UnitId, NextPos}) ->
    [UnitObj] = db:read(local_obj, UnitId),

    add_move_unit(UnitObj#local_obj.global_pos,
                  UnitObj#local_obj.player,
                  UnitId,
                  NextPos,
                  8);

add_battle_action(none) ->
    lager:info("NPC Unit doing nothing.").

add_move_unit(GlobalPos, Player, UnitId, NewPos, NumTicks) ->
    %Update unit state
    local:update_state(UnitId, moving),
    
    %Create event data
    EventData = {GlobalPos,
                 Player,
                 UnitId,
                 NewPos},

    game:add_event(self(), move_local_obj, EventData, NumTicks).

get_pos(Obj) ->
    {maps:get(<<"x">>, Obj), maps:get(<<"y">>, Obj)}.
