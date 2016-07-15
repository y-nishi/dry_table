# coding: utf-8
# デフォルトが utf-8なので、本当はマジックコメントは不要

require 'yaml'
require 'optparse'

class Table

  def initialize(filename, domain, dict)

    @filename = filename
    @root = extract_element(load_yaml(@filename), 'table')
    columns = extract_element(@root, 'columns')
    
    # nameを.で分割し、dictで変換
    columns.each do |e|
      e["pname"] = e["pname"] || 
        e["name"].split('.').inject(""){|r, e| r + (dict[e] || e) }
    end
    columns.map! do |e|
      # domain属性があれば、ドメインの定義を取得し、ドメインの属性で上書きする
      if e["domain"] && (domain_elements = domain[e["domain"]])
        domain_elements.merge(e)
      # type属性がない場合はname属性からドメイン定義を取得する。
      elsif !(e["type"]) && (domain_elements = domain[e["name"].delete('.')])
        domain_elements.merge(e)
      else
        e
      end
    end

  end

  def pname
    root["pname"] || File.basename(@filename, ".*")
  end
  
  def dump(node = @root)
    YAML.dump(node)
  end

end


def load_yaml(filename)
  (filename ? YAML.load_file(filename) : YAML.load(ARGF))
end

def extract_element(parsetree, element)
  if (ret = parsetree[element])
    ret
  else
    raise "#{element} element doesn't exist."
  end
end

DICTIONARY_CHECK_OPERATORS = {"geq" => ">=", "leq" => "<=", "equ" => "=", "neq" => "!=", "gtr" => ">", "lss" => "<"}


module Sql
  def get_create_ddl_table(table)

<<EOS
create table #{table.pname} (
#{table.columns_def(1)}
#{table.constraint(1)}
);
EOS

  end
  def get_create_ddl_table_comment(table)
    
    result = <<EOS
comment on table #{table.pname} is '#{table.name}';
EOS
    table.column.each do |i|
      result += <<EOS
comment on column #{table.pname}.#{i["pname"]} is '#{i["name"]}
EOS
    end
  result
  end

  def convert_check(check)
    DICTIONARY_CHECK_OPERATORS.each{|k, v| check.gsub!(/\b#{k}\b/, v)}
    check
  end

  def get_check(column)
    return "" unless column["check"]
    column["check"] = [column["check"]] unless column["check"].instance_of?(Array)
    column["check"].inject(""){|r, i| r + " CHECK(#{column["pname"]} #{convert_check(i)})"}
  end

  def get_size(column)
    (column["size"] ? "(" + column["size"].to_s + ")" : "")
  end

  def get_default(column)
    (column["default"] ? "DEFAULT #{column["default"]}" : "") 
  end

  def get_null(column)
    (column["nullable"] ? "" : " NOT NULL") 
  end

  def get_columns_def(columns)
    columns.inject("") do |r, e|
      r + (r == "" ? "" : ",") +
        "#{e["pname"]} #{e["type"]}#{get_size(e)}" +
        " #{get_default(e)}#{get_null(e)}#{get_check(e)}"
    end
  end

end

if __FILE__ == $PROGRAM_NAME
  params = ARGV.getopts("", "dic:", "dom:", "tab:")

  tab = Table.new(
    params["tab"], 
    extract_element(load_yaml(params["dom"]), 'domains'),
    extract_element(load_yaml(params["dic"]), 'dictionary')
  )
  puts tab.dump
end
