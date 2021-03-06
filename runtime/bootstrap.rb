require_relative '../lib/util.rb'
Constants = {}
Constants['Class'] = BikeClass.new('Class')
Constants['Class'].runtime_class = Constants['Class']
Constants['Object'] = BikeClass.new
Constants['Number'] = BikeClass.new('Object', 'Number')
Constants['Array'] = BikeClass.new('Object', 'Array')
Constants['String'] = BikeClass.new('Array', 'String')
Constants['Symbol'] = BikeClass.new('Object', 'Symbol')

root_self = Constants['Object'].new
RootContext = Context.new(root_self)

Constants['TrueClass'] = BikeClass.new
Constants['FalseClass'] = BikeClass.new
Constants['NilClass'] = BikeClass.new

Constants['true'] = Constants['TrueClass'].new_with_value(true, 'Bool')
Constants['false'] = Constants['FalseClass'].new_with_value(false, 'Bool')
Constants['nil'] = Constants['NilClass'].new_with_value(nil, 'Nil')

Constants['Class'].def :new do |receiver, arguments|
  new_receiver = receiver.new
  if new_receiver.runtime_class.runtime_methods['init']
    new_receiver.call('init', arguments, new_receiver)
  end
  new_receiver
end

Constants['Object'].def :'<|>' do |_, _|
end

Constants['Object'].def :observe_property do |receiver, arguments|
  receiver.observe arguments[1].ruby_value, arguments.first
  Constants['nil']
end

Constants['Object'].def :farity do |_, arguments|
  arg = arguments.first
  if arg.is_a?(BikeMethod)
    Constants['Number'].new_with_value(arg.params.length)
  elsif arg.is_a?(BikeObject) && arg.runtime_class.is_a?(BikeMethod)
    Constants['Number'].new_with_value(arg.runtime_class.params.length)
  end
end

Constants['Object'].def :println do |_, arguments|
  check_all_arguments(arguments)
  if arguments[0].ruby_value == '\\n' || arguments[0].ruby_value == '\\r'
    puts '\n'
  else
    puts arguments[0].ruby_value
  end
  arguments[0] || Constants['nil'] # We always want to return something
end
Constants['Object'].def :command do |_, arguments|
  if system(arguments.first.ruby_value)
    Constants['true']
  else
    Constants['false']
  end
end
Constants['Object'].def :wait do |_, arguments|
  sleep(arguments.first.ruby_value)
  Constants['true']
end
Constants['Object'].def :get_char do |_, _|
  begin
    system('stty raw -echo')
    str = STDIN.getc
  ensure
    system('stty -raw echo')
  end
  Constants['String'].new_with_value(if str == '\r'
                                       '\\r'
                                     elsif str == '\n'
                                       '\\n'
                                     else
                                       str
                                     end)
end

Constants['Object'].def :print do |_, arguments|
  check_all_arguments(arguments)
  if arguments[0].ruby_value == '\\n' || arguments[0].ruby_value == '\\r'
    print '\n'
  else
    print arguments[0].ruby_value
  end
  arguments[0] || Constants['nil']
end

def check_all_arguments(args)
  args.each_index do |i|
    arg = args[i]
    fail 'Nil argument at number #{i}!' unless arg
  end
end

Constants['Object'].def :call do |receiver, _|
  receiver
end
Constants['Number'].def :+ do|receiver, arguments|
  check_all_arguments(arguments)
  result = receiver.ruby_value + arguments.first.ruby_value
  Constants['Number'].new_with_value(result)
end
Constants['Number'].def :% do |receiver, arguments|
  Constants['Number'].new_with_value(receiver.ruby_value %
                                     arguments.first.ruby_value)
end
Constants['Number'].def :- do|receiver, arguments|
  check_all_arguments(arguments)
  result = receiver.ruby_value - arguments.first.ruby_value
  Constants['Number'].new_with_value(result)
end
Constants['Number'].def :< do|receiver, arguments|
  check_all_arguments(arguments)
  result = receiver.ruby_value < arguments.first.ruby_value
  Constants['Number'].new_with_value(result)
end
Constants['Number'].def :> do|receiver, arguments|
  check_all_arguments(arguments)
  result = receiver.ruby_value > arguments.first.ruby_value
  Constants['Number'].new_with_value(result)
end
Constants['Number'].def :<= do|receiver, arguments|
  check_all_arguments(arguments)
  result = receiver.ruby_value <= arguments.first.ruby_value
  Constants['Number'].new_with_value(result)
end
Constants['Number'].def :>= do|receiver, arguments|
  check_all_arguments(arguments)
  result = receiver.ruby_value >= arguments.first.ruby_value
  Constants['Number'].new_with_value(result)
end
Constants['Number'].def :* do|receiver, arguments|
  check_all_arguments(arguments)
  result = receiver.ruby_value * arguments.first.ruby_value
  Constants['Number'].new_with_value(result)
end
Constants['Number'].def :/ do|receiver, arguments|
  check_all_arguments(arguments)
  result = receiver.ruby_value / arguments.first.ruby_value
  Constants['Number'].new_with_value(result)
end

def define_is(type)
  Constants[type].def :is do|receiver, arguments|
    check_all_arguments(arguments)
    result = receiver.ruby_value == arguments.first.ruby_value
    if result
      Constants['true']
    else
      Constants['false']
    end
  end
end

def define_isnt(type)
  Constants[type].def :isnt do|receiver, arguments|
    check_all_arguments(arguments)
    result = receiver.ruby_value != arguments.first.ruby_value
    if result
      Constants['true']
    else
      Constants['false']
    end
  end
end

def define_and(type)
  Constants[type].def :and do|receiver, arguments|
    check_all_arguments(arguments)
    result = receiver.ruby_value && arguments.first.ruby_value
    if result
      Constants['true']
    else
      Constants['false']
    end
  end
end

def define_or(type)
  Constants[type].def :or do|receiver, arguments|
    check_all_arguments(arguments)
    result = receiver.ruby_value || arguments.first.ruby_value
    if result
      Constants['true']
    else
      Constants['false']
    end
  end
end

%w(Object TrueClass FalseClass Array String Number Class).each do |k|
  define_is(k)
  define_isnt(k)
  define_and(k)
  define_or(k)
end
Constants['Object'].def :not do|receiver, _|
  if !receiver.ruby_value
    Constants['true']
  else
    Constants['false']
  end
end

Constants['Array'].def :'@' do |receiver, arguments|
  (receiver.ruby_value[arguments[0].ruby_value]) || Constants['nil']
end

Constants['Array'].def :length do |reciever, _|
  Constants['Number'].new_with_value(reciever.ruby_value.length)
end
Constants['String'].def :length do |reciever, _|
  Constants['Number'].new_with_value(reciever.ruby_value.length)
end
Constants['Array'].def :uniq do |receiver, _|
  uniq_ary = receiver.ruby_value.map(&:ruby_value).uniq
  Constants['Array'].new_with_value(uniq_ary.map do |e|
    Constants['Object'].new_with_value(e)
  end)
end

Constants['Array'].def :set do |receiver, arguments|
  clone = receiver.ruby_value.clone
  clone[arguments[0].ruby_value] = arguments[1]
  Constants['Array'].new_with_value(clone)
end
Constants['Array'].def :length do |receiver, _|
  Constants['Number'].new_with_value(receiver.ruby_value.count) ||
    Constants['nil']
end
Constants['Array'].def :+ do |receiver, arguments|
  if  arguments.first.ruby_value.is_a?(Array)
    Constants['Array'].new_with_value(receiver.ruby_value +
      arguments.first.ruby_value)
  else
    Constants['Array'].new_with_value(receiver.ruby_value + [arguments.first])
  end
end
Constants['Array'].def :* do |receiver, arguments|
  Constants['Array'].new_with_value(receiver.ruby_value *
    arguments.first.ruby_value)
end
Constants['Array'].def :- do |receiver, arguments|
  a = receiver.ruby_value.clone
  rem = arguments.first
  a.delete_at(a.map(&:ruby_value).index(rem.ruby_value) || a.length)

  Constants['Array'].new_with_value(a)
end
Constants['Array'].def :/ do |receiver, arguments|
  na = []
  (receiver.ruby_value.length * arguments.first.ruby_value).times do ||
    na << Constants['Array'].new_with_value(
      receiver.ruby_value.slice!(0,
                                 arguments
                                   .first
                                   .ruby_value))
  end
  na = na.delete_if { |e| e.ruby_value == [] }
  Constants['Array'].new_with_value na
end

Constants['String'].def :'@' do |receiver, arguments|
  Constants['String'].new_with_value(receiver.ruby_value[arguments[0]
    .ruby_value]) || Constants['nil']
end
Constants['String'].def :+ do |receiver, arguments|
  Constants['String'].new_with_value(receiver.ruby_value +
                                     arguments.first.ruby_value)
end
Constants['String'].def :* do |receiver, arguments|
  Constants['String'].new_with_value(receiver.ruby_value *
                                     arguments.first.ruby_value)
end
Constants['String'].def :- do |receiver, arguments|
  Constants['String'].new_with_value(
    receiver.ruby_value.gsub(arguments.first.ruby_value, ''))
end
Constants['String'].def :/ do |receiver, arguments|
  ns = []
  (receiver.ruby_value.length * arguments.first.ruby_value).times do ||
    ns << Constants['Array'].new_with_value(
      receiver.ruby_value.slice!(0,
                                 arguments
                                   .first
                                   .ruby_value))
  end
  ns = ns.delete_if { |e| e.ruby_value == '' }
  Constants['String'].new_with_value ns
end
