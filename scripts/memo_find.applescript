-- memo_find.applescript
-- 用法: osascript memo_find.applescript <关键词>
-- 在全部账户/文件夹/备忘录里搜索（标题或正文），列出命中条目；只读

on run argv
	if (count of argv) < 1 then return "FIND_FAIL reason=missing_query"
	set q to item 1 of argv
	if q is "" then return "FIND_FAIL reason=missing_query"
	set hits to 0
	set out to ""
	tell application "Notes"
		repeat with a in accounts
			set an to name of a
			repeat with f in folders of a
				set fn to name of f
				repeat with n in notes of f
					set matched to false
					try
						if (name of n) contains q then set matched to true
					end try
					if not matched then
						try
							if (plaintext of n) contains q then set matched to true
						end try
					end if
					if matched then
						set hits to hits + 1
						set nid to "(id_read_failed)"
						try
							set nid to (id of n) as text
						end try
						set md to ""
						try
							set md to (modification date of n) as string
						end try
						set out to out & "HIT id=" & nid & " | " & (name of n) & " | folder: " & fn & " | account: " & an & " | modified: " & md & linefeed
					end if
				end repeat
			end repeat
		end repeat
	end tell
	if hits = 0 then return "NO_HIT query=" & q
	return "FIND_OK count=" & hits & linefeed & out
end run
