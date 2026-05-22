class_name URLResolver
extends RefCounted

var backend_origin := "http://127.0.0.1:8788"

func _init(origin := "http://127.0.0.1:8788") -> void:
	backend_origin = origin.rstrip("/")

func normalize_user_url(input_url: String) -> String:
	var s := input_url.strip_edges()
	if s == "":
		return "http://news.grid/"
	if not s.contains("://"):
		s = "http://" + s
	if not s.ends_with("/") and s.find("/", s.find("://") + 3) == -1:
		s += "/"
	return s

func resolve_to_backend(input_url: String) -> String:
	var fake := normalize_user_url(input_url)
	var host := _extract_host(fake)
	if host == "":
		host = "news.grid"
	var path := _extract_path_and_query(fake)
	return "%s/worldweb/%s%s" % [backend_origin, host, path]

func display_url_from_backend(resolved_url: String) -> String:
	var prefix := backend_origin + "/worldweb/"
	if not resolved_url.begins_with(prefix):
		return resolved_url
	var rem := resolved_url.substr(prefix.length())
	var slash := rem.find("/")
	if slash < 0:
		return "http://%s/" % rem
	var host := rem.substr(0, slash)
	var path := rem.substr(slash)
	return "http://%s%s" % [host, path]

func _extract_host(url: String) -> String:
	var i := url.find("://")
	if i < 0:
		return ""
	var rest := url.substr(i + 3)
	var slash := rest.find("/")
	if slash < 0:
		return rest
	return rest.substr(0, slash)

func _extract_path_and_query(url: String) -> String:
	var i := url.find("://")
	if i < 0:
		return "/"
	var rest := url.substr(i + 3)
	var slash := rest.find("/")
	if slash < 0:
		return "/"
	return rest.substr(slash)
