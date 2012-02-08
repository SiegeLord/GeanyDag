/*
 *
 *   Copyright (c) 2012, Pavel Sountsov
 *
 *   This source code is released for free distribution under the terms of the
 *   GNU General Public License.
 *
 */

module geanydag;

import tango.core.Array;
import tango.io.Stdout;
import tango.io.device.File;
import tango.text.Arguments;
import tango.text.convert.Format;
import tango.text.json.Json;

alias Json!(char).Value Value;
alias Json!(char).Composite Composite;

enum TMTagType
{
	tm_tag_undef_t = 0, /* Unknown type */
	tm_tag_class_t = 1, /* Class declaration */
	tm_tag_enum_t = 2, /* Enum declaration */
	tm_tag_enumerator_t = 4, /* Enumerator value */
	tm_tag_field_t = 8, /* Field (Java only) */
	tm_tag_function_t = 16, /* Function definition */
	tm_tag_interface_t = 32, /* Interface (Java only) */
	tm_tag_member_t = 64, /* Member variable of class/struct */
	tm_tag_method_t = 128, /* Class method (Java only) */
	tm_tag_namespace_t = 256, /* Namespace declaration */
	tm_tag_package_t = 512, /* Package (Java only) */
	tm_tag_prototype_t = 1024, /* Function prototype */
	tm_tag_struct_t = 2048, /* Struct declaration */
	tm_tag_typedef_t = 4096, /* Typedef */
	tm_tag_union_t = 8192, /* Union */
	tm_tag_variable_t = 16384, /* Variable */
	tm_tag_externvar_t = 32768, /* Extern or forward declaration */
	tm_tag_macro_t = 65536, /*  Macro (without arguments) */
	tm_tag_macro_with_arg_t = 131072, /* Parameterized macro */
	tm_tag_file_t = 262144, /* File (Pseudo tag) */
	tm_tag_other_t = 524288, /* Other (non C/C++/Java tag) */
	tm_tag_max_t = 1048575 /* Maximum value of TMTagType */
}

enum TMTagAttrType
{
	tm_tag_attr_none_t = 0, /* Undefined */
	tm_tag_attr_name_t = 1, /* Tag Name */
	tm_tag_attr_type_t = 2, /* Tag Type */
	tm_tag_attr_file_t = 4, /* File in which tag exists */
	tm_tag_attr_line_t = 8, /* Line number of tag */
	tm_tag_attr_pos_t = 16, /* Byte position of tag in the file (Obsolete) */
	tm_tag_attr_scope_t = 32, /* Scope of the tag */
	tm_tag_attr_inheritance_t = 64, /* Parent classes */
	tm_tag_attr_arglist_t = 128, /* Argument list */
	tm_tag_attr_local_t = 256, /* If it has local scope */
	tm_tag_attr_time_t = 512, /* Modification time (File tag only) */
	tm_tag_attr_vartype_t = 1024, /* Variable Type */
	tm_tag_attr_access_t = 2048, /* Access type (public/protected/private) */
	tm_tag_attr_impl_t = 4096, /* Implementation (e.g. virtual) */
	tm_tag_attr_lang_t = 8192, /* Language (File tag only) */
	tm_tag_attr_inactive_t = 16384, /* Inactive file (File tag only) */
	tm_tag_attr_pointer_t = 32768, /* Pointer type */
	tm_tag_attr_max_t = 65535 /* Maximum value */
}

enum : char
{
	TA_NAME = cast(char)200,
	TA_LINE,
	TA_LOCAL,
	TA_POS, /* Obsolete */
	TA_TYPE,
	TA_ARGLIST,
	TA_SCOPE,
	TA_VARTYPE,
	TA_INHERITS,
	TA_TIME,
	TA_ACCESS,
	TA_IMPL,
	TA_LANG,
	TA_INACTIVE,
	TA_POINTER
}

enum TagAccess : char
{
	Public = 'p',
	Protected = 'r',
	Private = 'v',
	Friend = 'f',
	Default = 'd',
	Unknown = 'x'
}

enum TagImplementation : char
{
	Virtual = 'v',
	Unknown = 'x'
}

struct TMTag
{
	TMTagAttrType Attributes = TMTagAttrType.tm_tag_attr_type_t;
	
	const(char)[] Name; /* Name of tag */
	TMTagType Type = TMTagType.tm_tag_undef_t; /* Tag Type */
	
	byte Local = 0; /* Is the tag of local scope */
	uint PointerOrder = 0;
	const(char)[] Arglist; /* Argument list (functions/prototypes/macros) */
	const(char)[] Scope; /* Scope of tag */
	const(char)[] Inheritance; /* Parent classes */
	const(char)[] VarType; /* Variable type (maps to struct for typedefs) */
	TagAccess Access = TagAccess.Public;
	TagImplementation Impl = TagImplementation.Virtual;
}

void WriteTag(File fp, TMTag tag)
{
	fp.write(Format("{}", tag.Name));
	if(tag.Attributes & TMTagAttrType.tm_tag_attr_type_t)
		fp.write(Format("{}{}", TA_TYPE, tag.Type));
	if(tag.Attributes & TMTagAttrType.tm_tag_attr_arglist_t)
		fp.write(Format("{}{}", TA_ARGLIST, tag.Arglist));
	/*if(tag.Attributes & TMTagAttrType.tm_tag_attr_line_t)
		fp.write(Format("%c%ld", TA_LINE, tag.line));*/
	if(tag.Attributes & TMTagAttrType.tm_tag_attr_local_t)
		fp.write(Format("{}{}", TA_LOCAL, tag.Local));
	if(tag.Attributes & TMTagAttrType.tm_tag_attr_scope_t)
		fp.write(Format("{}{}", TA_SCOPE, tag.Scope));
	if(tag.Attributes & TMTagAttrType.tm_tag_attr_inheritance_t)
		fp.write(Format("{}{}", TA_INHERITS, tag.Inheritance));
	if(tag.Attributes & TMTagAttrType.tm_tag_attr_pointer_t)
		fp.write(Format("{}{}", TA_POINTER, tag.PointerOrder));
	if(tag.Attributes & TMTagAttrType.tm_tag_attr_vartype_t)
		fp.write(Format("{}{}", TA_VARTYPE, tag.VarType));
	if(tag.Attributes & TMTagAttrType.tm_tag_attr_access_t)
		fp.write(Format("{}{}", TA_ACCESS, tag.Access));
	if(tag.Attributes & TMTagAttrType.tm_tag_attr_impl_t)
		fp.write(Format("{}{}", TA_IMPL, tag.Impl));
	fp.write("\n");
}

@property
void Error()
{
	throw new Exception("Something's wrong with the JSON file");
}

const(char)[] GetString(Composite comp, const(char)[] key)
{
	auto val = comp.value(key);
	if(val is null)
		return null;
	return val.toString();
}

Value[] GetArray(Composite comp, const(char)[] key)
{
	auto val = comp.value(key);
	if(val is null)
		return null;
	return val.toArray();
}

void ParseFunctionType(const(char)[] composite_type, out const(char)[] var_type, out const(char)[] arg_list)
{
	if(composite_type is null)
	{
		var_type = null;
		arg_list = null;
		return;
	}
	
	int nested_pars = 0;
	size_t idx = composite_type.length - 2;
	while(idx > 0)
	{
		if(composite_type[idx] == ')')
			nested_pars++;
		if(composite_type[idx] == '(')
		{
			if(nested_pars == 0)
				break;
			else
				nested_pars--;
		}
		idx--;
	}
	
	arg_list = composite_type[idx..$];
	var_type = composite_type[0..idx];
}

unittest
{
	const(char)[] var_type, arg_list;
	ParseFunctionType("void()", var_type, arg_list);
	assert(var_type == "void", var_type);
	assert(arg_list == "()", arg_list);
	
	ParseFunctionType("void(int a)", var_type, arg_list);
	assert(var_type == "void", var_type);
	assert(arg_list == "(int a)", arg_list);
	
	ParseFunctionType("int delegate()(int delegate() a)", var_type, arg_list);
	assert(var_type == "int delegate()", var_type);
	assert(arg_list == "(int delegate() a)", arg_list);
}

void AddConstructors(SArgs args, File fp, Value members_value, const(char)[] parent_scope, const(char)[] parent_name, const(char)[] template_args)
{
	if(members_value is null)
		return;
	
	auto members = members_value.toArray();
	if(members is null) Error;
	
	bool have_constructors = false;
	
	foreach(member_value; members)
	{
		auto member = member_value.toObject();
		if(member is null) Error;
		
		TMTag tag;
		
		tag.Name = GetString(member, "name");
		if(tag.Name is null) Error;
		
		if(tag.Name == "this")
		{
			bool skip_tag = false;
			have_constructors = true;
			
			tag.Name = parent_name;
			if(parent_scope != "")
			{
				tag.Scope = parent_scope[0..$-1];
				tag.Attributes |= TMTagAttrType.tm_tag_attr_scope_t;
			}
			tag.Type |= TMTagType.tm_tag_macro_with_arg_t;
			
			auto composite_type = GetString(member, "type");
			ParseFunctionType(composite_type, tag.VarType, tag.Arglist);
			if(tag.Arglist !is null)
				tag.Attributes |= TMTagAttrType.tm_tag_attr_arglist_t;
			
			tag.Arglist = template_args ~ tag.Arglist;
		
			switch(GetString(member, "protection"))
			{
				default:
				case "public":
					tag.Attributes |= TMTagAttrType.tm_tag_attr_access_t;
					tag.Access = TagAccess.Public;
					break;
				case "protected":
					tag.Attributes |= TMTagAttrType.tm_tag_attr_access_t;
					tag.Access = TagAccess.Protected;
					skip_tag = !args.AllowNonPublic;
					break;
				case "private":
					tag.Attributes |= TMTagAttrType.tm_tag_attr_access_t;
					tag.Access = TagAccess.Private;
					skip_tag = !args.AllowNonPublic;
					break;
				case "package":
					skip_tag = !args.AllowNonPublic;
					break;
			}
			
			if(!skip_tag)
				WriteTag(fp, tag);
		}
	}
	
	if(!have_constructors)
	{
		TMTag tag;
		tag.Name = parent_name;
		tag.Arglist = template_args ~ "()";
		tag.Access = TagAccess.Public;
		tag.Type |= TMTagType.tm_tag_macro_with_arg_t;
		tag.Attributes |= TMTagAttrType.tm_tag_attr_access_t | TMTagAttrType.tm_tag_attr_arglist_t;
		
		if(parent_scope != "")
		{
			tag.Scope = parent_scope[0..$-1];
			tag.Attributes |= TMTagAttrType.tm_tag_attr_scope_t;
		}
		
		WriteTag(fp, tag);
	}
}

void MakeMemberTags(SArgs args, File fp, Value members_value, lazy const(char)[] current_scope, bool global = false, const(char)[] template_args = "")
{
	if(members_value is null)
		return;
	
	auto members = members_value.toArray();
	if(members is null) Error;
	
	foreach(member_value; members)
	{
		bool skip_tag = false;
		bool is_single_template = false; // Template functions and template classes
		bool is_template = false;
		bool write_tag = true;
		auto member = member_value.toObject();
		if(member is null) Error;
		
		TMTag tag;
		
		tag.Name = GetString(member, "name");
		if(tag.Name is null) Error;
		
		if(tag.Name == "this" || tag.Name == "~this")
			continue;
		
		auto kind = GetString(member, "kind");
		if(kind is null) Error;
		switch(kind)
		{
			case "variable":
				tag.Type |= global ? TMTagType.tm_tag_variable_t : TMTagType.tm_tag_member_t;
				
				tag.VarType = GetString(member, "type");
				if(tag.VarType !is null)
					tag.Attributes |= TMTagAttrType.tm_tag_attr_vartype_t;

				break;
			case "function":
				tag.Type |= global ? TMTagType.tm_tag_function_t : TMTagType.tm_tag_method_t;
				
				auto composite_type = GetString(member, "type");
				ParseFunctionType(composite_type, tag.VarType, tag.Arglist);
				if(tag.VarType !is null)
					tag.Attributes |= TMTagAttrType.tm_tag_attr_vartype_t | TMTagAttrType.tm_tag_attr_arglist_t;
				
				break;
			case "class":
				if(tag.Name.find('(') == tag.Name.length)
				{
					tag.Type |= TMTagType.tm_tag_class_t;
					AddConstructors(args, fp, member.value("members"), current_scope, tag.Name, template_args);
					write_tag = false;
				}
				else
				{
					goto case "template";
				}
				
				break;
			case "template":
				is_template = true;
				tag.Type |= TMTagType.tm_tag_macro_with_arg_t;
				ParseFunctionType(tag.Name, tag.Name, tag.Arglist);
				if(tag.Arglist !is null)
					tag.Attributes |= TMTagAttrType.tm_tag_attr_arglist_t;
				
				auto arr = GetArray(member, "members");
				if(arr is null) Error;
				if(arr.length == 1)
				{
					auto sole_member = arr[0].toObject();
					if(sole_member is null) Error;
					auto sole_name = GetString(sole_member, "name");
					if(sole_name == tag.Name)
						is_single_template = true;
				}
				
				break;
			default:
		}
		
		switch(GetString(member, "protection"))
		{
			default:
			case "public":
				tag.Attributes |= TMTagAttrType.tm_tag_attr_access_t;
				tag.Access = TagAccess.Public;
				break;
			case "protected":
				tag.Attributes |= TMTagAttrType.tm_tag_attr_access_t;
				tag.Access = TagAccess.Protected;
				skip_tag = !args.AllowNonPublic;
				break;
			case "private":
				tag.Attributes |= TMTagAttrType.tm_tag_attr_access_t;
				tag.Access = TagAccess.Private;
				skip_tag = !args.AllowNonPublic;
				break;
			case "package":
				skip_tag = !args.AllowNonPublic;
				break;
		}
		
		/* For templates */
		tag.Arglist = template_args ~ tag.Arglist;
		
		if(current_scope != "")
		{
			tag.Scope = current_scope[0..$-1];
			tag.Attributes |= TMTagAttrType.tm_tag_attr_scope_t;
		}
		
		if(!skip_tag)
		{
			if(is_single_template)
			{
				MakeMemberTags(args, fp, member.value("members"), current_scope, global, tag.Arglist);
			}
			else
			{
				if(write_tag)
					WriteTag(fp, tag);
				MakeMemberTags(args, fp, member.value("members"), current_scope ~ tag.Name ~ tag.Arglist ~ ".", is_template ? global : false);
			}
		}
	}
}

struct SArgs
{
	bool AllowNonPublic = false;
}

void main(char[][] args)
{
	SArgs arg_struct;
	
	auto arguments = new Arguments;
	arguments("private").aliased('p').bind({arg_struct.AllowNonPublic = true;});
	if(!arguments.parse(args) || arguments(null).assigned.length < 2)
	{
		Stdout.formatln("Usage:\n {} input_filename.json output_filename.d.tags", args[0]);
		return;
	}
	
	auto json = new Json!(char);
	json.parse(cast(char[])File.get(arguments(null).assigned[1]));
	auto root = json.value().toArray();
	if(root is null)
		Error;
	
	auto fp = new File(arguments(null).assigned[2], File.WriteCreate);
	scope(exit) fp.close();
	
	fp.write("# format=tagmanager\n");
	
	foreach(modul_value; root)
	{
		auto modul = modul_value.toObject();
		if(modul is null) Error;
		
		auto modul_name = GetString(modul, "name");
		if(modul_name is null)
		{
			auto modul_file = GetString(modul, "file");
			if(modul_file is null) Error;
			
			modul_name = modul_file[0..$-2];
		}
		
		MakeMemberTags(arg_struct, fp, modul.value("members"), modul_name ~ ".", true);
	}
}
