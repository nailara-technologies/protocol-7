# kimi zenka : QuestionRequest wire protocol + decline fix [ 2026-08-04 ]

task : data/tasks/kimi-zenka-question-request-silent-hang-fix.md
fix  : src/kimi.wire.question_respond [ new ] + QuestionRequest branch in
       src/kimi.handler.ws_message. staged, unsigned, uncommitted.

## the wire shape [ ground truth : kimi_cli/wire/types.py + wire/server.py ]

QuestionRequest payload is NOT approval-shaped :

```json
{ "id" : "...", "tool_call_id" : "...",
  "questions" : [ { "question" : "...", "header" : "...",
      "options" : [ { "label" : "...", "description" : "..." } ],
      "multi_select" : false, "body" : "",
      "other_label" : "", "other_description" : "" } ] }
```

reply is a json-rpc SUCCESS response [ envelope id == request id ] with
result = QuestionResponse : `{ "request_id" : "...", "answers" : {} }`.
answers maps question-text -> chosen label [ comma-joined for multi ].
do not force-fit kimi.wire.approval_respond : its `{request_id, response}`
result fails QuestionResponse validation [ server logs error, resolves {} ].

## empty answers = the graceful decline

server-side [ wire/server.py _handle_response ] : empty/invalid answers or a
json-rpc error response all resolve the pending request with `{}`. the
AskUserQuestion tool treats `{}` as "user dismissed the question" and returns
a NON-error tool result telling the model to proceed on its own — exactly the
fall-through behavior wanted. a json-rpc error response also works but logs a
server-side error ; the empty-answers success response is the clean decline.

## kimi-web re-sends unanswered questions on every reconnect

the same QuestionRequest id [ 657eda84-... ] was re-sent ~10 times across
natural reconnects before the fix. unlike approvals there is no responded-set
tracking for questions and none is needed : each re-send is a fresh pending
request server-side, so just respond every time.

## live verification notes

- real-path verification beat synthesized frames : after `kimi.reload source`
  the still-pending real QuestionRequest was re-sent on the next natural
  reconnect and the new branch logged the full payload + sent the decline ;
  the previously-stuck task [ CB0FF0E ] resumed immediately.
- eval-code socket-swap capture works for outbound frames [ pipe + parse with
  Protocol::WebSocket::Frame->new ; ->append ; ->next ] BUT pipe() handles in
  the kimi zenka carry a :utf8 layer : syswrite dies with "syswrite() isn't
  allowed on :utf8 handles". binmode BOTH pipe ends after pipe().
- literal JSON through the cube command transport [ p7_command kimi.eval-code
  with q|{...}| ] is fragile : arrived corrupted [ JSON::from_json parse
  error with empty $@ ]. building JSON in-code via JSON::encode_json hit a
  transport-level "syntax error near '})'". prefer real-path triggers.

#,,,.,..,,.,,,.,,,...,,,.,...,,,.,,.,,,..,..,,..,,...,...,..,,,,,,,,,,,,,,.,.,
#JDTHPILRRYM7EBQGF2AXG34FNQWSRMWV7B3KDGSEICEUJ6IXS7PEXI4VJ2FXN2ECSM4GSQ2T7UZEM
#\\\|6FXHZFPDICPA63ZEXAE3L3DTS4A5AL3ZCKTD3ELYFBIUC577T3D \ / AMOS7 \ YOURUM ::
#\[7]NLDR4TJHKV7RLRTHTWQ55WFYKFUB2RH72FHZ2N2XEHGJEVJQ3MCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
