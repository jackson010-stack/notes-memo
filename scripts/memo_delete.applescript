-- memo_delete.applescript
-- 用法: osascript memo_delete.applescript <note_id> [purge]
-- 仅接受 x-coredata://…/ICNote/p… 精确 id
-- 默认删除 = 移入「最近删除」（30 天内可恢复）；追加 purge = 再删一次彻底清除（不可恢复）
-- 删除后全库扫描确认；输出 DELETE_OK / DELETE_UNCONFIRMED / DELETE_REFUSED / DELETE_FAIL

on run argv
	if (count of argv) < 1 then return "DELETE_REFUSED reason=missing_id"
	set nid to item 1 of argv
	set purgeFlag to false
	if (count of argv) >= 2 then
		if (item 2 of argv) is "purge" then set purgeFlag to true
	end if
	if nid does not start with "x-coredata://" then return "DELETE_REFUSED reason=id_format id=" & nid
	if nid does not contain "ICNote/p" then return "DELETE_REFUSED reason=id_format id=" & nid
	
	set noteName to ""
	tell application "Notes"
		try
			set theNote to note id nid
		on error
			return "DELETE_FAIL reason=note_not_found id=" & nid
		end try
		try
			set noteName to name of theNote
		end try
		try
			delete theNote
		on error errMsg
			return "DELETE_FAIL reason=" & errMsg & " id=" & nid
		end try
		delay 0.8
	end tell
	
	set locFolder to ""
	set locAccount to ""
	repeat 4 times
		set locFolder to ""
		set locAccount to ""
		tell application "Notes"
			repeat with a in accounts
				repeat with f in folders of a
					repeat with n in notes of f
						try
							if ((id of n) as text) is nid then
								set locFolder to name of f
								set locAccount to name of a
							end if
						end try
					end repeat
				end repeat
			end repeat
		end tell
		if locFolder is not "" then exit repeat
		delay 0.5
	end repeat
	
	if locFolder is "" then return "DELETE_OK id=" & nid & " name=" & noteName & " purged=true"
	
	set inTrash to (locFolder is "Recently Deleted") or (locFolder is "最近删除")
	
	if inTrash and purgeFlag then
		tell application "Notes"
			try
				delete (note id nid)
			on error errMsg
				return "DELETE_UNCONFIRMED id=" & nid & " still_in=" & locFolder & "/" & locAccount & " purge_error=" & errMsg
			end try
			delay 1.0
		end tell
		set locFolder2 to ""
		tell application "Notes"
			repeat with a in accounts
				repeat with f in folders of a
					repeat with n in notes of f
						try
							if ((id of n) as text) is nid then set locFolder2 to name of f
						end try
					end repeat
				end repeat
			end repeat
		end tell
		if locFolder2 is "" then return "DELETE_OK id=" & nid & " name=" & noteName & " purged=true"
		return "DELETE_UNCONFIRMED id=" & nid & " still_in=" & locFolder2 & " name=" & noteName
	end if
	
	if inTrash then return "DELETE_OK id=" & nid & " name=" & noteName & " trash=" & locFolder & "/" & locAccount
	return "DELETE_UNCONFIRMED id=" & nid & " still_in=" & locFolder & "/" & locAccount & " name=" & noteName
end run
