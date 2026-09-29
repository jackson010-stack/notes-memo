-- memo_write.applescript
-- 用法: osascript memo_write.applescript <正文文件> [文件夹] [账户] [note_id]
-- 新建或更新一条备忘录；回读 plaintext 硬校验通过后才输出 MEMO_OK
-- 正文格式：UTF-8 文本，第一行 = 标题；空行保留；& < > 自动转义

on run argv
	if (count of argv) < 1 then return "MEMO_FAIL reason=missing_body_file"
	set bodyFilePath to item 1 of argv
	set folderArg to ""
	set accountArg to ""
	set noteIdArg to ""
	if (count of argv) >= 2 then set folderArg to item 2 of argv
	if (count of argv) >= 3 then set accountArg to item 3 of argv
	if (count of argv) >= 4 then set noteIdArg to item 4 of argv
	
	try
		set rawText to read (POSIX file bodyFilePath) as «class utf8»
	on error
		return "MEMO_FAIL reason=read_file_failed path=" & bodyFilePath
	end try
	if rawText is "" then return "MEMO_FAIL reason=empty_body"
	
	set rawNorm to my normalizeNewlines(rawText)
	set linesList to my trimEdgeEmptyLines(my splitLines(rawNorm))
	if (count of linesList) = 0 then return "MEMO_FAIL reason=empty_body"
	set htmlText to my linesToHTML(linesList)
	set origCmp to my normalizeForCompare(rawNorm)
	
	tell application "Notes"
		if accountArg is not "" then
			try
				set targetAccount to account accountArg
			on error
				return "MEMO_FAIL reason=account_not_found account=" & accountArg
			end try
		else
			try
				set targetAccount to account "iCloud"
			on error
				set targetAccount to account 1
			end try
		end if
		
		if folderArg is not "" then
			try
				set targetFolder to folder folderArg of targetAccount
			on error
				return "MEMO_FAIL reason=folder_not_found folder=" & folderArg
			end try
		else
			try
				set targetFolder to folder "Notes" of targetAccount
			on error
				try
					set targetFolder to folder "备忘录" of targetAccount
				on error
					set targetFolder to folder 1 of targetAccount
				end try
			end try
		end if
		set folderName to name of targetFolder
		
		if noteIdArg is not "" then
			try
				set theNote to note id noteIdArg
			on error
				return "MEMO_FAIL reason=note_not_found id=" & noteIdArg
			end try
			set body of theNote to htmlText
		else
			set theNote to make new note at targetFolder with properties {body:htmlText}
		end if
		
		delay 0.6
		set noteId to ""
		set noteName to ""
		set pt to ""
		repeat 5 times
			try
				set noteId to (id of theNote) as text
				set noteName to name of theNote
				set pt to plaintext of theNote
			end try
			if pt is not "" then exit repeat
			delay 0.5
		end repeat
	end tell
	
	if noteIdArg is not "" then
		set realFolder to ""
		tell application "Notes"
			repeat with a in accounts
				repeat with f in folders of a
					repeat with n in notes of f
						try
							if ((id of n) as text) is noteId then set realFolder to name of f
						end try
					end repeat
				end repeat
			end repeat
		end tell
		if realFolder is not "" then set folderName to realFolder
	end if
	
	set gotCmp to my normalizeForCompare(pt)
	if gotCmp is not origCmp then
		set d to my firstDiff(origCmp, gotCmp)
		return "MEMO_FAIL reason=mismatch line=" & (item 1 of d) & " orig=«" & (item 2 of d) & "» got=«" & (item 3 of d) & "» id=" & noteId & " name=" & noteName
	end if
	
	return "MEMO_OK id=" & noteId & " name=" & noteName & " folder=" & folderName & " chars=" & (count of pt)
end run

-- ---------- helpers ----------

on normalizeNewlines(t)
	set t to my replaceAll(t, (return & linefeed), linefeed)
	set t to my replaceAll(t, return, linefeed)
	return t
end normalizeNewlines

on splitLines(t)
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to linefeed
	set parts to text items of t
	set AppleScript's text item delimiters to oldDelims
	return parts
end splitLines

on trimEdgeEmptyLines(linesList)
	set lst to linesList
	repeat
		if (count of lst) = 0 then exit repeat
		if my trim(item 1 of lst) is not "" then exit repeat
		if (count of lst) = 1 then return {}
		set lst to items 2 thru -1 of lst
	end repeat
	repeat
		if (count of lst) = 0 then exit repeat
		if my trim(item -1 of lst) is not "" then exit repeat
		if (count of lst) = 1 then return {}
		set lst to items 1 thru -2 of lst
	end repeat
	return lst
end trimEdgeEmptyLines

on linesToHTML(linesList)
	set out to {}
	repeat with ln in linesList
		set s to my trim(ln as text)
		if s is "" then
			copy "<div><br></div>" to end of out
		else
			copy "<div>" & my htmlEscape(s) & "</div>" to end of out
		end if
	end repeat
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to ""
	set res to out as text
	set AppleScript's text item delimiters to oldDelims
	return res
end linesToHTML

on htmlEscape(s)
	set s to my replaceAll(s, "&", "&amp;")
	set s to my replaceAll(s, "<", "&lt;")
	set s to my replaceAll(s, ">", "&gt;")
	return s
end htmlEscape

on normalizeForCompare(t)
	set t to my normalizeNewlines(t)
	set linesList to my splitLines(t)
	set cleaned to {}
	repeat with ln in linesList
		set s to my trim(ln as text)
		set s to my replaceAll(s, tab, space)
		set s to my collapseSpaces(s)
		copy s to end of cleaned
	end repeat
	repeat
		if (count of cleaned) = 0 then exit repeat
		if (item 1 of cleaned) is not "" then exit repeat
		if (count of cleaned) = 1 then
			set cleaned to {}
			exit repeat
		end if
		set cleaned to items 2 thru -1 of cleaned
	end repeat
	repeat
		if (count of cleaned) = 0 then exit repeat
		if (item -1 of cleaned) is not "" then exit repeat
		if (count of cleaned) = 1 then
			set cleaned to {}
			exit repeat
		end if
		set cleaned to items 1 thru -2 of cleaned
	end repeat
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to linefeed
	set res to cleaned as text
	set AppleScript's text item delimiters to oldDelims
	return res
end normalizeForCompare

on firstDiff(a, b)
	set la to my splitLines(a)
	set lb to my splitLines(b)
	set maxN to count of la
	if (count of lb) > maxN then set maxN to count of lb
	repeat with i from 1 to maxN
		set sa to "(缺)"
		set sb to "(缺)"
		if i <= (count of la) then set sa to item i of la
		if i <= (count of lb) then set sb to item i of lb
		if sa is not sb then return {i, my truncateStr(sa, 40), my truncateStr(sb, 40)}
	end repeat
	return {0, "", ""}
end firstDiff

on truncateStr(s, n)
	if (count of s) <= n then return s
	return text 1 thru n of s & "…"
end truncateStr

on collapseSpaces(t)
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to space
	set parts to text items of t
	set AppleScript's text item delimiters to oldDelims
	set out to ""
	set isFirst to true
	repeat with p in parts
		set ps to p as text
		if ps is not "" then
			if isFirst then
				set out to ps
				set isFirst to false
			else
				set out to out & space & ps
			end if
		end if
	end repeat
	return out
end collapseSpaces

on trim(t)
	set s to t as text
	repeat
		if (count of s) = 0 then exit repeat
		set ch to character 1 of s
		if ch is space or ch is tab then
			if (count of s) = 1 then return ""
			set s to text 2 thru -1 of s
		else
			exit repeat
		end if
	end repeat
	repeat
		if (count of s) = 0 then exit repeat
		set ch to character (count of s) of s
		if ch is space or ch is tab then
			if (count of s) = 1 then return ""
			set s to text 1 thru -2 of s
		else
			exit repeat
		end if
	end repeat
	return s
end trim

on replaceAll(t, findStr, replStr)
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to findStr
	set parts to text items of t
	set AppleScript's text item delimiters to replStr
	set res to parts as text
	set AppleScript's text item delimiters to oldDelims
	return res
end replaceAll
