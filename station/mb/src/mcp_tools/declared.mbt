// Each tool as tools/list declares it (its name, description and parameters), byte for byte as station/src declares
// it: written down from the TypeScript once, held to it by station/test/mb-mcp-tools.test.ts. chat_create's runtimes
// are the station's (`Consts.runtime_kinds`), put in for "$RUNTIME_KINDS".

///|
let decl_chat_post : String =
  #|{
  #|  "name": "chat_post",
  #|  "description": "Post a message to one of your conversations, in Markdown (Slack and Feishu draw it too; Formatting in your instructions says what differs). kind ends your turn with it; card carries what people answer by choosing or typing (skill stillfail-chats: cards, held posts). With only to and title it names the conversation, nothing posted or ended.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "to": {
  #|        "type": "string",
  #|        "description": "CHANNEL/THREAD_TS: the thread attribute of the message you are answering."
  #|      },
  #|      "send": {
  #|        "type": "string",
  #|        "description": "The id of a post held back (its chat_post answered it): sends it as written. Give only to, send and the state the turn now ends with (kind, need, done, about)."
  #|      },
  #|      "withdraw": {
  #|        "type": "string",
  #|        "description": "The message ts of your own answer card to withdraw, its question resolved or obsolete. With to alone: nothing is sent and no turn ends."
  #|      },
  #|      "text": {
  #|        "type": "string",
  #|        "description": "The message, formatted for where it goes (posted as written). With a card: what it asks and the facts it turns on, answerable from this message alone."
  #|      },
  #|      "kind": {
  #|        "type": "string",
  #|        "enum": [
  #|          "all_done",
  #|          "need_human"
  #|        ],
  #|        "description": "Omit for a progress update. all_done: nothing in the chat is left unfinished; give done. need_human: a person has to give, do or decide something (a card you posted included); give need. Only for a real unresolved need: a factual answer alone needs no follow-up question."
  #|      },
  #|      "need": {
  #|        "type": "string",
  #|        "description": "For need_human (required): what the person has to give, do or decide, in one sentence in their language (要 Stripe 的测试 key); to verify something, where, how and what to look at; work of yours still running, after the ask (选统计口径；CI 还在跑)."
  #|      },
  #|      "about": {
  #|        "type": "string",
  #|        "description": "With kind: the ts of the message here the state is about (all_done: the result's; need_human: the one that asks, by default the card still waiting there, or this post's own). People's lists jump to it."
  #|      },
  #|      "done": {
  #|        "type": "string",
  #|        "description": "For all_done (required): why nothing in the chat is left, in their language: what was finished and where it landed or how it was confirmed, naming the evidence (已合进 main 82f108a5，测试版 1389 已发). Not just 做完了 or done: that is refused."
  #|      },
  #|      "files": {
  #|        "type": "array",
  #|        "items": {
  #|          "type": "string"
  #|        },
  #|        "description": "Absolute paths of files on this machine to attach (up to 10, 50 MB each), shown below the text unless it places one by name (Formatting in your instructions)."
  #|      },
  #|      "title": {
  #|        "type": "string",
  #|        "description": "The conversation's name in still.fail lists (nothing is renamed in Slack): a few words on what it is about, in their language, at most 30 characters. Another only when the chat has moved to something else, not to reword it: the station changes it rarely, and never over a name people gave."
  #|      },
  #|      "card": {
  #|        "type": "object",
  #|        "description": "What people answer this message with, in the chat and in their 待处理: options, text (a value they type) or login (one the login tool started). It does not end your turn: end need_human. A newer card replaces the previous one. A person's next message closes it, a decision or not: ask again with a new card if it is still needed.",
  #|        "properties": {
  #|          "type": {
  #|            "type": "string",
  #|            "enum": [
  #|              "options",
  #|              "text",
  #|              "login"
  #|            ]
  #|          },
  #|          "login": {
  #|            "type": "string",
  #|            "description": "For a login card (required): the id the login tool's start answered."
  #|          },
  #|          "station": {
  #|            "type": "string",
  #|            "description": "For a login card on another station's login: that station's key."
  #|          },
  #|          "options": {
  #|            "type": "array",
  #|            "description": "For an options card (required): the answers (1 to 6).",
  #|            "items": {
  #|              "type": "object",
  #|              "properties": {
  #|                "label": {
  #|                  "type": "string",
  #|                  "description": "A short phrase that reads on its own, in their language (按今天累计, 先不改)."
  #|                },
  #|                "detail": {
  #|                  "type": "string",
  #|                  "description": "One line on what choosing it leads to."
  #|                },
  #|                "recommended": {
  #|                  "type": "boolean",
  #|                  "description": "The one you recommend (at most one); the card shows it last."
  #|                },
  #|                "action": {
  #|                  "type": "string",
  #|                  "enum": [
  #|                    "reply",
  #|                    "close"
  #|                  ],
  #|                  "description": "reply (default) sends you the chosen label. close ends this need_human with no message and without waking you (you are told the choice with what you are next handed): only where choosing it needs no further work (不需要部署)."
  #|                }
  #|              },
  #|              "required": [
  #|                "label"
  #|              ],
  #|              "additionalProperties": false
  #|            }
  #|          },
  #|          "assignee": {
  #|            "type": "string",
  #|            "description": "The email of the person who must decide, from the conversation: the card is in their 待处理 alone. Always set it."
  #|          },
  #|          "placeholder": {
  #|            "type": "string",
  #|            "description": "For a text card: a hint shown in the empty field (sk_test_…)."
  #|          }
  #|        },
  #|        "required": [
  #|          "type"
  #|        ],
  #|        "additionalProperties": false
  #|      }
  #|    },
  #|    "required": [
  #|      "to"
  #|    ],
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_slack_api : String =
  #|{
  #|  "name": "slack_api",
  #|  "description": "Call any Slack Web API method as your Slack bot, e.g. conversations.history, users.info, reactions.add, chat.update, chat.postMessage in a channel, conversations.open then chat.postMessage for a direct message. A chat that did not start in Slack calls as the station's Slack bot. Writes in a thread another session takes part in are refused; posting in a thread nobody else is in, or a new message, makes that thread one of your conversations. Prefer chat_post to answer the thread you are working in. To see a file in another thread (a screenshot), read it with save_files: its url_private does not open for you.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "method": {
  #|        "type": "string",
  #|        "description": "The Web API method, e.g. \"conversations.replies\"."
  #|      },
  #|      "params": {
  #|        "type": "object",
  #|        "description": "Its arguments as Slack documents them (blocks and other structures as JSON values).",
  #|        "additionalProperties": true
  #|      },
  #|      "to": {
  #|        "type": "string",
  #|        "description": "CHANNEL/THREAD_TS of one of your Slack conversations: whose bot to call as. Default: this session's own connect."
  #|      },
  #|      "save_files": {
  #|        "type": "boolean",
  #|        "description": "Also save the files in the answer (conversations.replies, conversations.history, files.info) into your workspace's uploads. The answer starts with saved_files, their local paths, and not_saved, why any could not be."
  #|      },
  #|      "bot": {
  #|        "type": "string",
  #|        "description": "Which of the station's Slack bots to call as, by its id or name, when the chat has none of its own and the station has several (the error names them). Default: the one bound to your runtime."
  #|      }
  #|    },
  #|    "required": [
  #|      "method"
  #|    ],
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_chat_state : String =
  #|{
  #|  "name": "chat_state",
  #|  "description": "Record how this turn ends without posting another message (End every turn, in your instructions): all_done, need_human (about points to your visible question unless a card is pending: need alone is not shown in the chat) or waiting (only work you started that brings you back by itself, with nothing else left to do meanwhile; waiting on a person is need_human).",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "kind": {
  #|        "type": "string",
  #|        "enum": [
  #|          "all_done",
  #|          "need_human",
  #|          "waiting"
  #|        ]
  #|      },
  #|      "need": {
  #|        "type": "string",
  #|        "description": "For need_human (required): as chat_post's need."
  #|      },
  #|      "about": {
  #|        "type": "string",
  #|        "description": "The ts of the message in your conversation the state is about (all_done: the result's; need_human: the one where you visibly ask what is still needed, required unless a card is pending; waiting: the one saying what you started). People's lists jump to it."
  #|      },
  #|      "done": {
  #|        "type": "string",
  #|        "description": "For all_done (required): as chat_post's done."
  #|      },
  #|      "seconds": {
  #|        "type": "integer",
  #|        "minimum": 10,
  #|        "maximum": 3600,
  #|        "description": "For waiting: how long until the work brings you back; if nothing has by then, you are asked again (not with watch). A fallback only: something must watch the work. Where it truly cannot be watched, the shortest it could take."
  #|      },
  #|      "for": {
  #|        "type": "string",
  #|        "description": "For waiting (required): what you wait for, in a few words people read under your name, in their language (e.g. 安卓滑动测试在模拟器上跑完)."
  #|      },
  #|      "watch": {
  #|        "type": "boolean",
  #|        "description": "For waiting: true when all you wait on is your watch keeping on (job_start with watch): people see the chat as watching, and the clock does not ask you again. Left out when you wait on anything else, even with a watch running."
  #|      }
  #|    },
  #|    "required": [
  #|      "kind"
  #|    ],
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_chat_leave : String =
  #|{
  #|  "name": "chat_leave",
  #|  "description": "Stop following a Slack, Feishu or group thread you are in, when people there ask (stop watching, 别跟了): its messages stop reaching you until someone mentions you there again, which brings you back. Tell them so in the thread first. You can still read it with chat_history and post there.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "to": {
  #|        "type": "string",
  #|        "description": "CHANNEL/THREAD_TS: the thread to leave."
  #|      }
  #|    },
  #|    "required": [
  #|      "to"
  #|    ],
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_chat_history : String =
  #|{
  #|  "name": "chat_history",
  #|  "description": "Read earlier messages of one of your conversations, oldest first, your own posts included.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "to": {
  #|        "type": "string",
  #|        "description": "CHANNEL/THREAD_TS: the thread attribute of the message you are answering."
  #|      },
  #|      "before": {
  #|        "type": "string",
  #|        "description": "Only messages older than this message ts."
  #|      },
  #|      "limit": {
  #|        "type": "integer",
  #|        "minimum": 1,
  #|        "maximum": 200,
  #|        "description": "Default 30."
  #|      }
  #|    },
  #|    "required": [
  #|      "to"
  #|    ],
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_chat_list : String =
  #|{
  #|  "name": "chat_list",
  #|  "description": "List conversations on this station (or another/all stations of the workspace), latest first: each with address, title, agents (runtime, model, effort, creator, running), last message and link; then chats shared by other workspaces. Filter by query, model, created_by or archived.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "query": {
  #|        "type": "string",
  #|        "description": "Only conversations whose title, last message or agents contain this (case-insensitive)."
  #|      },
  #|      "model": {
  #|        "type": "string",
  #|        "description": "Only conversations with an agent whose model contains this (case-insensitive, e.g. carbon)."
  #|      },
  #|      "created_by": {
  #|        "type": "string",
  #|        "description": "Only conversations started by this email (or \"me\" for whoever started your chat)."
  #|      },
  #|      "archived": {
  #|        "type": "boolean",
  #|        "description": "false: only active (unarchived) chats; true: only archived chats. Omit for both."
  #|      },
  #|      "station": {
  #|        "type": "string",
  #|        "description": "Another station of the workspace (name or id), or \"all\" for every station. Omit for this station."
  #|      },
  #|      "limit": {
  #|        "type": "integer",
  #|        "minimum": 1,
  #|        "maximum": 100,
  #|        "description": "Default 20."
  #|      }
  #|    },
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_chat_read : String =
  #|{
  #|  "name": "chat_read",
  #|  "description": "Read the messages of any conversation, not only your own, oldest first: one on this station or, by its link, on another station of the workspace or one another workspace shares with this one.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "chat": {
  #|        "type": "string",
  #|        "description": "The chat: its link as people give it (…/chats/<key>, …/o/<workspace>/<station>/<key>), a thread address CHANNEL/THREAD_TS, or a session key (reads that session's chat)."
  #|      },
  #|      "before": {
  #|        "type": "string",
  #|        "description": "Only messages older than this message ts."
  #|      },
  #|      "limit": {
  #|        "type": "integer",
  #|        "minimum": 1,
  #|        "maximum": 200,
  #|        "description": "Default 30."
  #|      },
  #|      "fetch": {
  #|        "type": "array",
  #|        "items": {
  #|          "type": "string"
  #|        },
  #|        "description": "A chat on another station: its attachments to fetch here although large, by the paths listed there. Those up to 16 MB come by themselves, their paths replaced with where they are here."
  #|      }
  #|    },
  #|    "required": [
  #|      "chat"
  #|    ],
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_session_send : String =
  #|{
  #|  "name": "session_send",
  #|  "description": "Send a message to another session's agent: a chat on this station, on another station of the workspace, or one another workspace shares with this one to write to. Its agent takes it like any message, headed with a link to your chat, and it stays out of that chat's conversation. It answers you the same way, so to wait for the answer end your turn waiting. Use chat_post for your own conversations.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "to": {
  #|        "type": "string",
  #|        "description": "The other chat: its link (…/chats/<key>, …/o/<workspace>/<station>/<key>, the link a message from it is headed with), its session key, or a thread address CHANNEL/THREAD_TS on this station."
  #|      },
  #|      "text": {
  #|        "type": "string",
  #|        "description": "The message, standing on its own: what you need or found, with what the other agent needs to act on it. Markdown."
  #|      },
  #|      "files": {
  #|        "type": "array",
  #|        "items": {
  #|          "type": "string"
  #|        },
  #|        "description": "Absolute local paths of files to attach (at most 10, each up to 50 MB): copied to that chat, and its agent gets their paths there."
  #|      }
  #|    },
  #|    "required": [
  #|      "to",
  #|      "text"
  #|    ],
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_chat_create : String =
  #|{
  #|  "name": "chat_create",
  #|  "description": "Open a still.fail chat with its own agent, here or on another workspace station. for: me means you lead it (it asks you and reports each turn; end waiting to await it); person means your person owns it (no reports to you). text starts it; session_send writes to its link. Retry uncertain calls with the same key. See skills stillfail-chats and stillfail-leading.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "for": {
  #|        "type": "string",
  #|        "enum": [
  #|          "me",
  #|          "person"
  #|        ],
  #|        "description": "me: you lead it; person: your person's."
  #|      },
  #|      "key": {
  #|        "type": "string",
  #|        "description": "Your name for it: the same key again gives the same chat."
  #|      },
  #|      "text": {
  #|        "type": "string",
  #|        "description": "The first message, standing on its own: what its agent is to do and what it needs to do it (it does not see your chat). Markdown."
  #|      },
  #|      "title": {
  #|        "type": "string",
  #|        "description": "The chat's name, in their language (up to 120 characters). Its agent names it when left out."
  #|      },
  #|      "station": {
  #|        "type": "string",
  #|        "description": "Another station of the workspace to open it on, by its name or id. Left out: this station."
  #|      },
  #|      "runtime": {
  #|        "type": "string",
  #|        "enum": "$RUNTIME_KINDS",
  #|        "description": "Its agent's runtime (dsh: DeepSeek Harness, grok: Grok Build, cursor: Cursor, devin: Devin, hermes: Hermes Agent, agy: Antigravity CLI, pi: Pi). Default: that of its model."
  #|      },
  #|      "model": {
  #|        "type": "string",
  #|        "description": "Its agent's model. Default: the one the person it goes to uses most on that station, when one clearly leads; else it is not opened and you are told which to ask them about."
  #|      },
  #|      "effort": {
  #|        "type": "string",
  #|        "description": "Its agent's reasoning effort. Default: the one that person has opened most chats with on that runtime and model there lately, else its model's."
  #|      },
  #|      "speed": {
  #|        "type": "string",
  #|        "enum": [
  #|          "standard",
  #|          "fast",
  #|          "ultrafast"
  #|        ],
  #|        "description": "Overrides fast. Ultrafast needs a supported Codex model and eligible ChatGPT plan."
  #|      },
  #|      "fast": {
  #|        "type": "boolean",
  #|        "description": "Fast mode."
  #|      },
  #|      "context": {
  #|        "type": "integer",
  #|        "description": "The most context it runs with, in tokens."
  #|      },
  #|      "preset": {
  #|        "type": "string",
  #|        "description": "One of this station's presets, by name or id, taken as it is (skill stillfail-chats). Left out: none."
  #|      },
  #|      "files": {
  #|        "type": "array",
  #|        "items": {
  #|          "type": "string"
  #|        },
  #|        "description": "Absolute local paths of files to attach to the first message (at most 10, each up to 50 MB): copied to that chat, and its agent gets their paths there."
  #|      }
  #|    },
  #|    "required": [
  #|      "for",
  #|      "key",
  #|      "text"
  #|    ],
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_chat_archive : String =
  #|{
  #|  "name": "chat_archive",
  #|  "description": "Archive another still.fail chat on this station or another station of your workspace. As when a person archives it in the app, its own session goes with it: its running turn can finish, and its jobs and services stop. The chat and its messages remain, but its workspace files may later be cleaned up. Calling again on an already manually archived chat leaves it as it was.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "chat": {
  #|        "type": "string",
  #|        "description": "Another chat's link, or its thread address or session key on this station; chat_list finds them."
  #|      }
  #|    },
  #|    "required": [
  #|      "chat"
  #|    ],
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_chat_configure : String =
  #|{
  #|  "name": "chat_configure",
  #|  "description": "Read or change a session's runtime, model, effort, speed, context, preset or ownership (for), on this station or another station of the workspace. Omit change fields to inspect its current config; omit chat (or pass \"self\") for your own session. Changes take effect on the next turn (or once the running turn ends) and post a notice in that chat. Skill stillfail-chats says more.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "chat": {
  #|        "type": "string",
  #|        "description": "Target chat: its link (…/chats/<key>, …/o/…/<key>), session key, or local thread address CHANNEL/THREAD_TS. Omit or \"self\" for this session."
  #|      },
  #|      "runtime": {
  #|        "type": "string",
  #|        "enum": "$RUNTIME_KINDS",
  #|        "description": "New runtime. Default: current, or inferred from model."
  #|      },
  #|      "model": {
  #|        "type": "string",
  #|        "description": "New model id (e.g. gemini-4-neon, claude-opus-5-5), or empty string for the runtime's default."
  #|      },
  #|      "effort": {
  #|        "type": "string",
  #|        "description": "New reasoning effort, or empty string for the model's default."
  #|      },
  #|      "speed": {
  #|        "type": "string",
  #|        "enum": [
  #|          "standard",
  #|          "fast",
  #|          "ultrafast"
  #|        ],
  #|        "description": "Generation speed."
  #|      },
  #|      "fast": {
  #|        "type": "boolean",
  #|        "description": "Fast mode."
  #|      },
  #|      "context": {
  #|        "type": "integer",
  #|        "minimum": 0,
  #|        "description": "Max context tokens (0 resets to the model's full window)."
  #|      },
  #|      "preset": {
  #|        "type": "string",
  #|        "description": "Apply a preset's model config from this station by name or id (cannot combine with runtime/model/effort/speed/fast/context)."
  #|      },
  #|      "repick": {
  #|        "type": "boolean",
  #|        "description": "Hand account selection back to the station and repick now."
  #|      },
  #|      "for": {
  #|        "type": "string",
  #|        "enum": [
  #|          "me",
  #|          "person"
  #|        ],
  #|        "description": "Change ownership: \"me\" to lead this chat as your sub-chat, \"person\" to hand it back to people."
  #|      }
  #|    },
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_session_history : String =
  #|{
  #|  "name": "session_history",
  #|  "description": "Read a session's execution history, as the pages show it: what its agent thought, the tools it called and what they returned, numbered #0 onwards. The latest entries unless before is given. A session on another station of the workspace is read by its chat's link.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "chat": {
  #|        "type": "string",
  #|        "description": "Whose: a session key, a chat's link (…/chats/<key>, …/o/…/<key>, or an execution history link with ?history=<key>&entry=<n>, which shows the entries around n), or a thread address CHANNEL/THREAD_TS with one agent."
  #|      },
  #|      "before": {
  #|        "type": "integer",
  #|        "minimum": 0,
  #|        "description": "Only entries before #before (the reply says where older ones start)."
  #|      },
  #|      "limit": {
  #|        "type": "integer",
  #|        "minimum": 1,
  #|        "maximum": 200,
  #|        "description": "Default 40."
  #|      },
  #|      "max_chars": {
  #|        "type": "integer",
  #|        "minimum": 100,
  #|        "maximum": 4000,
  #|        "description": "Each entry cut to this many characters. Default 1500."
  #|      }
  #|    },
  #|    "required": [
  #|      "chat"
  #|    ],
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_archive_policy : String =
  #|{
  #|  "name": "archive_policy",
  #|  "description": "Read or change this station's archive policy: after an agent ends a turn all_done, a decision model reads the chat and picks one of the policy's options; the chat is recommended for archiving when that option counts as archive. Each option is a situation counted as archive or not. Without arguments, returns the current policy. Change it when a person says archive recommendations are wrong in a way the policy causes; when the model only picked the wrong option, say so and leave the policy. Tell the person in the chat what you changed: people see who changed it, from which chat, and what.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "policy": {
  #|        "type": "string",
  #|        "description": "The new policy in words, whole (omit to keep it)."
  #|      },
  #|      "options": {
  #|        "type": "array",
  #|        "description": "The new options, whole and in order (omit to keep them); 2 to 20, at least one archive and one not.",
  #|        "items": {
  #|          "type": "object",
  #|          "properties": {
  #|            "id": {
  #|              "type": "string",
  #|              "description": "The option's id as read (lowercase letters, digits, _): keep each existing one's; omit for a new one."
  #|            },
  #|            "name": {
  #|              "type": "string",
  #|              "description": "A few words, in the language people use."
  #|            },
  #|            "rubric": {
  #|              "type": "string",
  #|              "description": "One line: when a chat is in this situation."
  #|            },
  #|            "archive": {
  #|              "type": "boolean",
  #|              "description": "Whether a chat in this situation is recommended for archiving."
  #|            }
  #|          },
  #|          "required": [
  #|            "name",
  #|            "rubric",
  #|            "archive"
  #|          ],
  #|          "additionalProperties": false
  #|        }
  #|      }
  #|    },
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_station_list : String =
  #|{
  #|  "name": "station_list",
  #|  "description": "List the stations of this workspace, and this station's sandboxes, with how busy each is and what it has (cores, arch/OS, GPU, CPU busy, load, free memory and disk, what it runs, relay ping), to pick where station_task runs. There are no locks between agents: never wait for, ask for or announce one; start the task and the station queues it when it must. One with mode: \"tasks\" only runs tasks and is its owner's: where it says this chat may not use it (thisChat), ask with station_use. One listed unprotected cannot be called from here and says why: not a bug, tell the person. unanswered is not offline; version_seen is an old copy. Skill stillfail-jobs (Another station) says how to choose.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "station": {
  #|        "type": "string",
  #|        "description": "One station, in detail, with whether it accepts tasks and its file limits."
  #|      }
  #|    },
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_station_task : String =
  #|{
  #|  "name": "station_task",
  #|  "description": "Run a shell task on another station of this workspace, or in a sandbox of this station's (station_list lists both). action prepare records command and name under a key you choose; upload inputs with station_file; action start runs it once, queued there when it must be, and you are told here when it ends. After an uncertain answer use the same key again; a new key is new work. On a station it runs as that station's OS user, not confined. All tasks of this session there share one directory, removed with anything still running when this chat is archived or deleted, or after 14 days unused: bring back what must last. With dir, each start first syncs that directory to a mirror there and runs the command in it; when start answers syncing: true, call start again with the same key. action clean deletes a mirror with everything in it, results not brought back included. Skill stillfail-jobs (Another station) says the rest: the queue, the screen, small tasks, mirrors, what comes back.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "station": {
  #|        "type": "string"
  #|      },
  #|      "key": {
  #|        "type": "string"
  #|      },
  #|      "action": {
  #|        "enum": [
  #|          "prepare",
  #|          "start",
  #|          "get",
  #|          "log",
  #|          "stop",
  #|          "release",
  #|          "list",
  #|          "mirrors",
  #|          "clean"
  #|        ],
  #|        "description": "get, log (lines) and stop address the task of key. release, on a task some of whose results could not be saved, lets another task use its mirror: keep them with station_file first. list and mirrors need only station; clean, station and mirror."
  #|      },
  #|      "mirror": {
  #|        "type": "string",
  #|        "description": "Name returned by action mirrors; action clean removes this one mirror."
  #|      },
  #|      "command": {
  #|        "type": "string"
  #|      },
  #|      "name": {
  #|        "type": "string"
  #|      },
  #|      "lines": {
  #|        "type": "integer"
  #|      },
  #|      "dir": {
  #|        "type": "string",
  #|        "description": "prepare: an absolute path of a directory here, synced before each start (what Git tracks or would add, only what changed)."
  #|      },
  #|      "back": {
  #|        "type": "array",
  #|        "items": {
  #|          "type": "string"
  #|        },
  #|        "description": "prepare: paths relative to where the command runs, downloaded when it ends into station-back/<key> of this workspace (removed once nothing in it changed for 6 hours: move what you keep)."
  #|      },
  #|      "screen": {
  #|        "type": "boolean",
  #|        "description": "prepare: the task has the screen (windows, simulators) from start to end. For one command of it, run that as `stillfail-job screen <command>` instead."
  #|      },
  #|      "small": {
  #|        "type": "boolean",
  #|        "description": "A brief one-CPU offscreen task (not a build, test suite, video or screen work)."
  #|      }
  #|    },
  #|    "required": [
  #|      "station",
  #|      "action"
  #|    ],
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_station_file : String =
  #|{
  #|  "name": "station_file",
  #|  "description": "Upload an input before starting a remote task, or download a task artifact to this session. path is relative to this session's directory on that station; local is a path in this session workspace. Files are transferred in chunks, up to 1 GiB each; repeat upload after a disconnect. Downloads never overwrite an existing local file. Post downloaded artifacts using chat_post files.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "station": {
  #|        "type": "string"
  #|      },
  #|      "key": {
  #|        "type": "string"
  #|      },
  #|      "direction": {
  #|        "enum": [
  #|          "upload",
  #|          "download"
  #|        ]
  #|      },
  #|      "path": {
  #|        "type": "string"
  #|      },
  #|      "local": {
  #|        "type": "string"
  #|      }
  #|    },
  #|    "required": [
  #|      "station",
  #|      "key",
  #|      "direction",
  #|      "path",
  #|      "local"
  #|    ],
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_workspace_limit : String =
  #|{
  #|  "name": "workspace_limit",
  #|  "description": "Read or change this chat's soft workspace-size limit on one station (10 GiB by default). When a working chat exceeds its limit, the station tells its agent and repeats hourly until it cleans up or raises the limit; it never deletes files or stops work for this.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "station": {
  #|        "type": "string",
  #|        "description": "A station this chat has used for its remote workspace there, by name or id; omit for this station."
  #|      },
  #|      "limit_gib": {
  #|        "type": "integer",
  #|        "minimum": 1,
  #|        "description": "New soft limit in whole GiB; omit to read it."
  #|      }
  #|    },
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_job_start : String =
  #|{
  #|  "name": "job_start",
  #|  "description": "Start a background job: a shell command the station runs apart from your turns, with its output kept in a log, for work that outlives a turn. You are told when it ends; inside it, `stillfail-job notify <words>` sends you a message on the way (milestones, problems). With port it is a web service: kept up (started again if it ends), given PORT in its environment, and opened by the workspace's members through the link returned (post it where people should see it). With watch it keeps watch over something for a long while (a CI run, a deploy, a metric, a review queue): its chat shows as watching and is not archived for being idle. Skill stillfail-jobs says the rest: waiting on a job, how a watch checks and notifies, services.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "command": {
  #|        "type": "string",
  #|        "description": "The shell command (run by sh -c)."
  #|      },
  #|      "name": {
  #|        "type": "string",
  #|        "description": "A short name for it."
  #|      },
  #|      "cwd": {
  #|        "type": "string",
  #|        "description": "Where it runs; default this session's workspace."
  #|      },
  #|      "port": {
  #|        "type": "integer",
  #|        "minimum": 1024,
  #|        "maximum": 65535,
  #|        "description": "For a web service: the port it listens on (127.0.0.1 is enough)."
  #|      },
  #|      "watch": {
  #|        "type": "boolean",
  #|        "description": "It keeps watch for a long while. Not with a port."
  #|      }
  #|    },
  #|    "required": [
  #|      "command"
  #|    ],
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_job_list : String =
  #|{
  #|  "name": "job_list",
  #|  "description": "This session's background jobs, newest first: their state (running, exited, stopped, failed), exit code, port and link.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {},
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_job_log : String =
  #|{
  #|  "name": "job_log",
  #|  "description": "The last lines of a background job's output.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "id": {
  #|        "type": "string"
  #|      },
  #|      "lines": {
  #|        "type": "integer",
  #|        "minimum": 1,
  #|        "maximum": 1000,
  #|        "description": "Default 50."
  #|      }
  #|    },
  #|    "required": [
  #|      "id"
  #|    ],
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_job_stop : String =
  #|{
  #|  "name": "job_stop",
  #|  "description": "Stop a background job (a service is then not started again).",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "id": {
  #|        "type": "string"
  #|      }
  #|    },
  #|    "required": [
  #|      "id"
  #|    ],
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_screen : String =
  #|{
  #|  "name": "screen",
  #|  "description": "The screens of this station a person can see and drive from their still.fail app (this machine's display; tabs of the station's browser; the iOS Simulators booted on this Mac), each with who is viewing or controlling it now and the link that opens it there. When a person has to act on one (log in, solve a captcha, approve a prompt), post its link on a line of its own with chat_post kind=need_human and end your turn; call this again to see whether someone is on it. To see and operate one yourself, use the computer tool with its id.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "id": {
  #|        "type": "string",
  #|        "description": "One screen's id (desktop, browser:<targetId>, simulator:<udid>); default: all of them"
  #|      },
  #|      "action": {
  #|        "type": "string",
  #|        "enum": [
  #|          "list",
  #|          "take_control",
  #|          "disconnect",
  #|          "watch_only",
  #|          "disconnect_all"
  #|        ],
  #|        "description": "list (default). The others act on people's views of the screen `id`, and only when a person asked for it in this chat (\"you take control\"): never by your own choice to get past being refused input. take_control makes every person's view only look, its picture going on, so your input by coordinates goes through; they take it back with one tap. disconnect and watch_only act on one `view`; disconnect_all ends every person's view."
  #|      },
  #|      "view": {
  #|        "type": "string",
  #|        "description": "A view's id, from `on` in the list."
  #|      }
  #|    },
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_permissions : String =
  #|{
  #|  "name": "permissions",
  #|  "description": "What macOS lets still.fail Helper do on this station's Mac: Screen Recording and Accessibility (people seeing and driving the screen, the computer tool on the desktop) and the folders macOS protects (Documents, Desktop, Downloads, removable and network disks, for people's drive); and the station's own Local Network access (devices on the LAN reaching it straight). Your own commands do not get these. With request, puts the helper's window asking for that one grant up on the Mac (not again while it is up, nor within 3 minutes of being shown) and says how a person gives it: post that with chat_post kind=need_human and end your turn; call this again to see whether it was granted.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "request": {
  #|        "type": "string",
  #|        "enum": [
  #|          "capture",
  #|          "control",
  #|          "documents",
  #|          "desktop",
  #|          "downloads",
  #|          "removable",
  #|          "network",
  #|          "localNetwork"
  #|        ],
  #|        "description": "A grant to ask a person for: capture (Screen Recording), control (Accessibility), documents, desktop, downloads, removable, network (network disks), localNetwork (Local Network)"
  #|      }
  #|    },
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_computer : String =
  #|{
  #|  "name": "computer",
  #|  "description": "Operate one of this station's screens yourself (the `screen` tool lists them: desktop, browser:<tab>, simulator:<udid>): take a screenshot, click, move, drag, scroll, type text, press keys, in pixels of the latest screenshot of that screen. On the desktop prefer an app's accessibility tree (action=tree with app; no app: the apps running): each element is a line with its ref (e12), which click, type, set and scroll act on without the pointer or the focus, also while a person drives the screen. Use screenshots for what has no tree (a canvas, a game, a picture). For web pages prefer the browser's DevTools (the `browser` tool). While a person is controlling the screen your input by coordinates is refused: wait, or ask them in the chat. Skill stillfail-browser says more.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "action": {
  #|        "type": "string",
  #|        "enum": [
  #|          "screenshot",
  #|          "tree",
  #|          "click",
  #|          "move",
  #|          "drag",
  #|          "scroll",
  #|          "type",
  #|          "set",
  #|          "key",
  #|          "wait"
  #|        ],
  #|        "description": "What to do (default screenshot)"
  #|      },
  #|      "screen": {
  #|        "type": "string",
  #|        "description": "The screen's id from the `screen` tool"
  #|      },
  #|      "x": {
  #|        "type": "number",
  #|        "description": "click, move, scroll: the point, in screenshot pixels from the left"
  #|      },
  #|      "y": {
  #|        "type": "number",
  #|        "description": "click, move, scroll: the point, in screenshot pixels from the top"
  #|      },
  #|      "button": {
  #|        "type": "string",
  #|        "enum": [
  #|          "left",
  #|          "right",
  #|          "middle"
  #|        ],
  #|        "description": "click, drag: the mouse button (default left)"
  #|      },
  #|      "double": {
  #|        "type": "boolean",
  #|        "description": "click: a double click"
  #|      },
  #|      "from": {
  #|        "type": "array",
  #|        "items": {
  #|          "type": "number"
  #|        },
  #|        "minItems": 2,
  #|        "maxItems": 2,
  #|        "description": "drag: [x, y] where the button goes down"
  #|      },
  #|      "to": {
  #|        "type": "array",
  #|        "items": {
  #|          "type": "number"
  #|        },
  #|        "minItems": 2,
  #|        "maxItems": 2,
  #|        "description": "drag: [x, y] where it is released"
  #|      },
  #|      "dx": {
  #|        "type": "number",
  #|        "description": "scroll: pixels to the right (negative: left)"
  #|      },
  #|      "dy": {
  #|        "type": "number",
  #|        "description": "scroll: pixels down (negative: up)"
  #|      },
  #|      "text": {
  #|        "type": "string",
  #|        "description": "type: the text, as if typed (a newline presses Enter); set: the element's new value (on Windows type by ref is refused, as it needs the focus: use set)"
  #|      },
  #|      "key": {
  #|        "type": "string",
  #|        "description": "key: a key or a combination, e.g. Enter, Escape, Tab, ArrowDown, PageDown, F5, a, ctrl+shift+t, cmd+c and cmd+Left on a Mac (on Windows cmd is the Windows key: ctrl+c there)"
  #|      },
  #|      "mods": {
  #|        "type": "array",
  #|        "items": {
  #|          "type": "string",
  #|          "enum": [
  #|            "cmd",
  #|            "ctrl",
  #|            "alt",
  #|            "shift"
  #|          ]
  #|        },
  #|        "description": "key: modifiers held besides those in key"
  #|      },
  #|      "ms": {
  #|        "type": "number",
  #|        "description": "wait: how long (ms, at most 30000) before the screenshot"
  #|      },
  #|      "app": {
  #|        "type": "string",
  #|        "description": "tree: the app whose window to read (its name, e.g. Finder); key: send the keys to this app without focusing it"
  #|      },
  #|      "window": {
  #|        "type": "string",
  #|        "description": "tree: one of the app's windows, by the id a tree answer names (when it has several)"
  #|      },
  #|      "ref": {
  #|        "type": "string",
  #|        "description": "click, type, set, scroll: the element, by its ref in the latest tree (e12); tree: read only the part under it"
  #|      },
  #|      "skeleton": {
  #|        "type": "boolean",
  #|        "description": "tree: only the window's outline (containers say how much is inside), for a big window"
  #|      },
  #|      "tree": {
  #|        "type": "boolean",
  #|        "description": "After an action by ref: read the app's tree again (default true)"
  #|      },
  #|      "wait": {
  #|        "type": "number",
  #|        "description": "After an action: ms before its screenshot (default 500), or before the tree is read again (by ref: default 200)"
  #|      },
  #|      "screenshot": {
  #|        "type": "boolean",
  #|        "description": "After an action: return a screenshot (default true)"
  #|      }
  #|    },
  #|    "required": [
  #|      "screen"
  #|    ],
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_peer_forward : String =
  #|{
  #|  "name": "peer_forward",
  #|  "description": "Forward a TCP port of another station of this workspace to this machine, like `ssh -L`: a listener on 127.0.0.1 here whose connections reach localhost:<port> on that station, bytes passed as they are. For what a browser or a non-HTTP client uses (web pages and dev servers, databases, a Chrome's DevTools port); a program that only calls an HTTP API with a base URL needs no forward: $STILLFAIL_PEER_HTTP/<station>/<port>. A forward is this session's: it closes when this chat is archived or deleted, after 30 minutes with no connection, or when this station restarts (open it again). With no arguments, lists this session's forwards. Skill stillfail-jobs (Another station's services) says more.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "station": {
  #|        "type": "string",
  #|        "description": "The station: its name from station_list (any case), or its id."
  #|      },
  #|      "port": {
  #|        "type": "integer",
  #|        "minimum": 1,
  #|        "maximum": 65535,
  #|        "description": "The port on that station's localhost."
  #|      },
  #|      "local_port": {
  #|        "type": "integer",
  #|        "minimum": 1,
  #|        "maximum": 65535,
  #|        "description": "Where here (127.0.0.1); default the same as port when free, else any free one."
  #|      },
  #|      "job": {
  #|        "type": "string",
  #|        "description": "One of your jobs (job_start's id): the forward closes when it ends."
  #|      },
  #|      "close": {
  #|        "type": "integer",
  #|        "minimum": 1,
  #|        "maximum": 65535,
  #|        "description": "A forward's local port: closes it."
  #|      }
  #|    },
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_relays : String =
  #|{
  #|  "name": "relays",
  #|  "description": "Manage this workspace's relays. list shows relay URLs, disabled routes and registered mesh nodes. add probes an https iroh relay URL before sharing it with workspace stations and devices; no approval needed. remove removes a URL; at most 4 own URLs. enroll (name) issues a private one-use token valid for 24 hours, granting forwarding only. revoke (node) removes a mesh relay through its issuing station, which must be reachable.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "action": {
  #|        "type": "string",
  #|        "enum": [
  #|          "list",
  #|          "add",
  #|          "remove",
  #|          "enroll",
  #|          "revoke"
  #|        ]
  #|      },
  #|      "node": {
  #|        "type": "string",
  #|        "description": "Mesh relay public key from list (revoke)."
  #|      },
  #|      "name": {
  #|        "type": "string",
  #|        "description": "Name for a new mesh relay (enroll)."
  #|      },
  #|      "url": {
  #|        "type": "string",
  #|        "description": "The relay's URL (add, remove)."
  #|      }
  #|    },
  #|    "required": [
  #|      "action"
  #|    ],
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_feedback_send : String =
  #|{
  #|  "name": "feedback_send",
  #|  "description": "Report a bug in still.fail itself to its team after the person has seen and approved what will be sent. See the stillfail-feedback skill.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "to": {
  #|        "type": "string",
  #|        "description": "CHANNEL/THREAD_TS of the conversation the problem came up in."
  #|      },
  #|      "title": {
  #|        "type": "string",
  #|        "description": "One line: what goes wrong (at most 200 characters)."
  #|      },
  #|      "body": {
  #|        "type": "string",
  #|        "description": "Markdown: what happened, what was expected, how to get there, when, and anything else the team needs to find it. Only what the person agreed to send."
  #|      },
  #|      "area": {
  #|        "type": "string",
  #|        "enum": [
  #|          "station",
  #|          "web",
  #|          "android",
  #|          "desktop",
  #|          "slack",
  #|          "cloud",
  #|          "unknown"
  #|        ],
  #|        "description": "The part of still.fail it is in, as far as you can tell."
  #|      },
  #|      "desktopPlatform": {
  #|        "type": "string",
  #|        "enum": [
  #|          "macos",
  #|          "windows"
  #|        ],
  #|        "description": "Affected desktop app OS, when known."
  #|      },
  #|      "reporter": {
  #|        "type": "string",
  #|        "description": "Who reports it: their name and where they said it (e.g. \"Ada, Slack #ops\")."
  #|      },
  #|      "logs": {
  #|        "type": "string",
  #|        "description": "Optional: the lines of the station's own logs or tool errors that show the problem (at most 64 KB). No secrets, no people's content."
  #|      }
  #|    },
  #|    "required": [
  #|      "to",
  #|      "title",
  #|      "body"
  #|    ],
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_feedback_reply : String =
  #|{
  #|  "name": "feedback_reply",
  #|  "description": "Answer the still.fail team on a bug report this station sent (FB-<number>), when the person you work for asks you to (for example after handing you the team's reply): what they asked for, or what the person says. Only what that person agreed to send; it is kept with the report for the team and the chat's people to read.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "number": {
  #|        "type": "integer",
  #|        "description": "The report's number: 12 for FB-12."
  #|      },
  #|      "text": {
  #|        "type": "string",
  #|        "description": "Markdown: the answer (at most 8000 characters). No secrets."
  #|      }
  #|    },
  #|    "required": [
  #|      "number",
  #|      "text"
  #|    ],
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_station_move : String =
  #|{
  #|  "name": "station_move",
  #|  "description": "Move this station's chats, accounts, jobs and connects to another station of its workspace, one item or all, and back. Read skill stillfail-move first: it says each option. plan {to}: a summary; module (after, limit) pages, item one. move {to, module, item}: one item (a chat: its session key); withNeeds: its needs first; all: everything, once a card is confirmed in the app. back {module, item, to}: back here. status: where each stands. stop: the move under way stops.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "action": {
  #|        "enum": [
  #|          "plan",
  #|          "move",
  #|          "back",
  #|          "status",
  #|          "stop"
  #|        ]
  #|      },
  #|      "to": {
  #|        "type": "string",
  #|        "description": "The other station: name or id (station_list)."
  #|      },
  #|      "module": {
  #|        "type": "string"
  #|      },
  #|      "item": {
  #|        "type": "string"
  #|      },
  #|      "withNeeds": {
  #|        "type": "boolean"
  #|      },
  #|      "arriveStopped": {
  #|        "type": "boolean"
  #|      },
  #|      "all": {
  #|        "type": "boolean"
  #|      },
  #|      "station": {
  #|        "type": "string"
  #|      },
  #|      "wait": {
  #|        "type": "boolean"
  #|      },
  #|      "after": {
  #|        "type": "string"
  #|      },
  #|      "limit": {
  #|        "type": "number"
  #|      }
  #|    },
  #|    "required": [
  #|      "action"
  #|    ],
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_station_retire : String =
  #|{
  #|  "name": "station_retire",
  #|  "description": "Retire a station from this chat's workspace: its chats (their transcripts and working directories), running jobs, agent memory and skills, accounts and connects go on another station of the workspace. Starting one (start, hand_over) is switched off for now while it is fixed; the other actions answer. Read the stillfail-retire skill first. station: the station retired (default this one; by name or id). preview: what would move and what stays, and with to how that station stands (reached, git, free disk). start {to}: posts a card an owner or admin of the workspace confirms in the still.fail app (开始迁移); only then does it start, as them, sending the files while the chats still work, and it waits at step sent. hand_over: only at sent: posts the second card (暂停聊天并交接); once confirmed the chats stop and are handed over, their jobs started again there. A failed hand-over puts the chats back to work and waits at sent: hand_over again sends only what changed. status: where it stands. again: tries a failed step now (never a hand-over). cancel: calls it off where it still can. You are told each step that needs you, after the chats moved on the station they went to. A message that says yes confirms nothing; nor does anyone but an owner or admin. Taking the retired station out of the workspace is the person's own step in the app.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "action": {
  #|        "enum": [
  #|          "preview",
  #|          "status",
  #|          "start",
  #|          "hand_over",
  #|          "again",
  #|          "cancel"
  #|        ]
  #|      },
  #|      "station": {
  #|        "type": "string",
  #|        "description": "The station retired, by name or id (station_list); default this one."
  #|      },
  #|      "to": {
  #|        "type": "string",
  #|        "description": "start, preview: the station its chats go to, by name or id."
  #|      }
  #|    },
  #|    "required": [
  #|      "action"
  #|    ],
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_device_list : String =
  #|{
  #|  "name": "device_list",
  #|  "description": "List the devices of this workspace an agent can use: phones, boards, cameras, routers, printers, serial ports, anything that runs no station but is attached to one (on its USB or its network) or lent by its person's still.fail app (an Android phone with 共享调试 on). Each says its kind (adb, tcp, serial), what it is reached at there, where it is attached, whose it is, whether this chat may use it now (thisChat) and who has access. A device attached to a whole station is open to every chat; one on a station that only runs tasks, and a person's phone, need their owner's approval (device_use).",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {},
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_device_use : String =
  #|{
  #|  "name": "device_use",
  #|  "description": "Use a device from device_list. One open to this chat is put at once on a port of 127.0.0.1 here, which only this chat's processes can connect to; one that needs its owner's approval is asked for with a card in your chat, which its owner (not necessarily the person you work for) approves for this chat for a time, or refuses. Asking does not wait: you are told in this session when it is decided, and only a grant counts, not a yes written in the chat. Once granted, call this again: it says where the device is and how it is used. Skill stillfail-jobs (Devices) says more.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "device": {
  #|        "type": "string",
  #|        "description": "The device: its name from device_list (any case), or its id; a person's email for their Android phone (lent once they approve). None: the phone of the person you work for."
  #|      },
  #|      "reason": {
  #|        "type": "string",
  #|        "description": "What you will do with it and why (shown on the card to its owner)."
  #|      },
  #|      "timeout": {
  #|        "type": "object",
  #|        "description": "How long the grant should last (the owner may choose another): idle (ends once this chat has not used the device that long) or fixed, in whole minutes from 1 minute to 30 days. Default: idle, 1 hour.",
  #|        "properties": {
  #|          "kind": {
  #|            "enum": [
  #|              "idle",
  #|              "fixed"
  #|            ]
  #|          },
  #|          "seconds": {
  #|            "type": "integer"
  #|          }
  #|        },
  #|        "required": [
  #|          "kind",
  #|          "seconds"
  #|        ],
  #|        "additionalProperties": false
  #|      },
  #|      "done": {
  #|        "type": "boolean",
  #|        "description": "Hand it back: end this chat's grant of it (or its request still pending), and close its port here. With no device named, every one this chat holds."
  #|      }
  #|    },
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_station_use : String =
  #|{
  #|  "name": "station_use",
  #|  "description": "Ask to use a station of this workspace that only runs tasks (station_list says mode: \"tasks\" for it, with whose it is and whether this chat may use it). A whole station needs no asking, nor one whose owner turned 免批准 on. A card in your chat says your reason, and its owner (not necessarily the person you work for) approves it for this chat, for a time, or refuses it. It does not wait: you are told in this session when it is decided, and only a grant counts, not a yes written in the chat. Once granted, use it as any station, by its name, until the grant ends: what this chat runs there is stopped then. Skill stillfail-jobs (Another station) says more.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "station": {
  #|        "type": "string",
  #|        "description": "The tasks-only station: its name from station_list (any case), or its id."
  #|      },
  #|      "reason": {
  #|        "type": "string",
  #|        "description": "What you will run there and why (shown on the card to its owner)."
  #|      },
  #|      "timeout": {
  #|        "type": "object",
  #|        "description": "How long the grant should last (the owner may choose another): idle (ends once this chat has not used that station that long) or fixed, in whole minutes from 1 minute to 30 days. Default: idle, 1 hour.",
  #|        "properties": {
  #|          "kind": {
  #|            "enum": [
  #|              "idle",
  #|              "fixed"
  #|            ]
  #|          },
  #|          "seconds": {
  #|            "type": "integer"
  #|          }
  #|        },
  #|        "required": [
  #|          "kind",
  #|          "seconds"
  #|        ],
  #|        "additionalProperties": false
  #|      },
  #|      "done": {
  #|        "type": "boolean",
  #|        "description": "Hand it back: end this chat's grant of it (or its request still pending). With no station named, every one this chat holds."
  #|      }
  #|    },
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_skill_read : String =
  #|{
  #|  "name": "skill_read",
  #|  "description": "Read a skill in full by its exact name: one a tool's description or your instructions name, when you do not have its file, or one found by search, with its station where that is another station of the workspace. With file, one of the Markdown reference files the reply lists. It only reads this workspace's skill catalog: nothing is installed, shared or run.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "name": {
  #|        "type": "string",
  #|        "description": "The skill's exact name."
  #|      },
  #|      "station": {
  #|        "type": "string",
  #|        "description": "The station's id or unique name from search. Omit for this station."
  #|      },
  #|      "file": {
  #|        "type": "string",
  #|        "description": "A Markdown filename listed by this skill (default SKILL.md)."
  #|      }
  #|    },
  #|    "required": [
  #|      "name"
  #|    ],
  #|    "additionalProperties": false
  #|  }
  #|}

///|
let decl_search : String =
  #|{
  #|  "name": "search",
  #|  "description": "Search everything in this workspace, on all its stations at once: chats (titles, archived ones too), every message, agents' execution histories, services and tasks, skills and memory, profiles, and the files on each station's machine (names and what they say). Words are matched anywhere in the text, case aside; every word must match. Results are grouped by station and kind, with chat links to give people or read with chat_read and session_history; a skill found is read in full with skill_read. Skill stillfail-chats says more.",
  #|  "inputSchema": {
  #|    "type": "object",
  #|    "properties": {
  #|      "query": {
  #|        "type": "string",
  #|        "description": "The words to find (at most 200 characters)."
  #|      },
  #|      "kinds": {
  #|        "type": "array",
  #|        "items": {
  #|          "enum": [
  #|            "chat",
  #|            "message",
  #|            "history",
  #|            "job",
  #|            "skill",
  #|            "memory",
  #|            "profile",
  #|            "file"
  #|          ]
  #|        },
  #|        "description": "Only these kinds. Left out: all."
  #|      },
  #|      "limit": {
  #|        "type": "integer",
  #|        "description": "At most this many of each kind on each station (default 5, at most 50)."
  #|      },
  #|      "station": {
  #|        "type": "string",
  #|        "description": "Only this station, by its name or id. Left out: every station of the workspace."
  #|      }
  #|    },
  #|    "required": [
  #|      "query"
  #|    ],
  #|    "additionalProperties": false
  #|  }
  #|}
