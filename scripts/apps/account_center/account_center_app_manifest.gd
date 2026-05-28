extends RefCounted

static func manifest(builder: Callable) -> Dictionary:
	return {
		"id": &"accounts",
		"title": "Accounts",
		"name": "Accounts",
		"description": "Manage user accounts, profile pictures, and login visibility.",
		"subtitle": "User accounts and profile pictures",
		"keywords": "accounts users profile login avatar",
		"category": "Administration",
		"pinned": true,
		"single_instance": true,
		"agent_visible": true,
		"agent_actions": ["accounts.get_state"],
		"builder": builder
	}
