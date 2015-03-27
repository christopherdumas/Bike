require_relative "parser"
require_relative "runtime"

$gc = 0
$is_set = {}
$saved_is_set = {}

def gensym (base="AnonymousClass_")
  $gc += 1
  r = "#{base}#{$gc}".to_sym

  r
end

# First, we create an simple wrapper class to encapsulate the interpretation process.
# All this does is parse the code and call eval on the node at the top of the AST.
class Interpreter
  def initialize
    @parser = Parser.new
  end

  def eval(code)
    @parser.parse(code).eval(RootContext)
  end
end
# The Nodes class will always be at the top of the AST. Its only purpose it to
# contain other nodes. It correspond to a block of code or a series of expressions.
#
# The eval method of every node is the "interpreter" part of our language.
# All nodes know how to evalualte themselves and return the result of their evaluation.
# The context variable is the Context in which the node is evaluated (local
# variables, current self and current class).
class Nodes
  def eval(context)
    return_value = nil
    nodes.each do |node|
      return_value = node.eval(context)
    end
    return_value || Constants["nil"] # Last result is return value (or nil if none).
  end
end

# We're using Constants that we created before when bootstrapping the runtime to access
# the objects and classes from inside the runtime.
#
# Next, we implement eval on other node types. Think of that eval method as how the
# node bring itself to life inside the runtime.
class NumberNode
  def eval(context)
    Constants["Number"].new_with_value(value, "Num")
  end
end

class StringNode
  def eval(context)
    Constants["String"].new_with_value(value, "String")
  end
end

class ArrayListNode
  def eval(context)
    new_value = []
    value.each do |e|
      e = e.eval(context)
      new_value << e
    end
    Constants["Array"].new_with_value(new_value, new_value.map(&:type))
  end
end

class TrueNode
  def eval(context)
    Constants["true"]
  end
end

class FalseNode
  def eval(context)
    Constants["false"]
  end
end

class NilNode
  def eval(context)
    Constants["nil"]
  end
end

class GetConstantNode
  def eval(context)
    Constants[name]
  end
end

class GetLocalNode
  def eval(context)
    context.locals[name] || Constants[name] || context.current_class.runtime_methods[name]
  end
end
class ImportNode
  def eval(context)
    if into == nil
      context.locals[file.downcase.sub '.bk', ''] = Interpreter.new.eval File.read(file)
    else
      context.locals[into] = Interpreter.new.eval File.read(file)
    end
  end
end

class SetLocalNode
  def eval(context)
    if !$is_set[name]
      context.locals[name] = value.eval(context)
      $is_set[name] = true
      context.locals[name]
    else
      raise "Attemt to re-assign variable using normal variable."
    end
  end
end

class SetLocalDescNode
  def eval(context)
    name.each do |name|
      if !$is_set[name]
        context.locals[name] = value.eval(context).call(name, [])
        $is_set[name] = true
      else
        raise "Attemt to re-assign variable using normal variable."
      end
    end
    Constants["nil"]
  end
end

class SetLocalAryNode
  def eval(context)
    context.locals[head] = array.eval(context).ruby_value[0]
    context.locals[tail] = Constants["Array"].new_with_value(array.eval(context).ruby_value.drop(1))
    Constants["nil"]
  end
end

class SetClassNode
  def eval (context)
    if bike_class
      klass = bike_class.eval(context)
    else
      klass = context.current_self
    end
    klass.runtime_methods[method] = lambda.eval(context)
    Constants["nil"]
  end
end


# The CallNode for calling a method is a little more complex. It needs to set the +receiver+
# first and then evaluate the +arguments+ before calling the method.
class CallNode
  def eval(context)
    if receiver
      value = receiver.eval(context)
    else
      value = context.current_self # Default to self if no receiver.
    end
    if !value
      raise "Receiver '#{receiver.name}' cannot be resolved by either getting current context, or through dot notation!"
    end

    if !is_splat
      evaluated_arguments = arguments.map { |arg| arg.eval(context) }
    else
      evaluated_arguments = arguments.eval(context)
      if !evaluated_arguments
        raise "Cannot find splatted argument identifier."
      else
        evaluated_arguments = evaluated_arguments.ruby_value.clone
      end
    end
    
    saved_is_set = $is_set
    $is_set = {}
    res = value.call(method, evaluated_arguments, context)
    $is_set = saved_is_set
    
    res
  end
end

class ApplyNode
  def eval(context)
    if !is_expr
      value = context.current_self
      if !value
        raise "Receiver cannot be resolved by getting current context!"
      end
      
      evaluated_arguments = arguments.map { |arg| arg.eval(context) }
      value.apply(context, method, evaluated_arguments)
    else
      evaluated_arguments = arguments.map { |arg| arg.eval(context) }
      method.eval(context).call(context.current_self, evaluated_arguments)
    end
  end
end

# Defining a method, using the +def+ keyword, is done by adding a method to the current class.
class DefNode
  def eval(context)
    method = BikeMethod.new(params, body, context, name)
    context.current_class.runtime_methods[name] = method
  end
end

class LambdaNode
  def eval(context)
    BikeMethod.new(params, body, context, vararg, false, "rec_func")
  end
end

# Defining a class is done in three steps:
#
# 1. Reopen or define the class.
# 2. Create a special context of evaluation (set current_self and current_class to the new class).
# 3. Evaluate the body of the class inside that context.
#
# Check back how DefNode was implemented, adding methods to context.current_class. Here is
# where we set the value of current_class.
class ClassNode
  def eval(context)
    classname = name || gensym()

    bike_class = Constants[classname] # Check if class is already defined

    unless bike_class # Class doesn't exist yet
      bike_class = BikeClass.new(superclass, [])
      Constants[classname] = bike_class # Define the class in the runtime
    end

    class_context = Context.new(bike_class, bike_class)
    context.locals.each do |name, value|
      class_context.locals[name] = value
    end
    body.eval(class_context)

    bike_class
  end
end

class HashNode
  def eval(context)
    bike_class = BikeClass.new("Object")

    class_context = Context.new(bike_class, bike_class)
    class_context.locals["self"] = bike_class

    key_values.each do |e|
      key = e[0]
      val = e[1]
      bike_class.def key.to_sym do |receiver, arguments|
        val.eval(class_context)
      end
    end
    bike_class.call("new", [])
  end
end

class PackageNode
  def eval(context)
    bike_class = BikeClass.new
    class_context = Context.new(bike_class, bike_class)
    class_context.locals["self"] = bike_class
    context.current_class.runtime_methods.each { |k, v| class_context.current_class.runtime_methods[k] = v }
    context.locals.each do |name, value| 
      class_context.locals[name] = value
    end
    body.eval(class_context)

    bike_class.call("new", [])
  end
end

# Finally, to implement if in our language,
# we turn the condition node into a Ruby value to use Ruby's if.
class IfNode
  def eval(context)
    if elseifs
      conditions = [condition] + elseifs.map(&:condition)
      bodys = [body] + elseifs.map(&:body)
    else
      conditions = [condition, TrueNode.new]
      bodys = [body, else_body]
    end
    conditions.each_with_index do |cond, i|
      if cond.eval(context).ruby_value && bodys[i] != nil
        return bodys[i].eval(context)
      end
    end
    Constants["nil"]
  end
end
class ForNode
  def eval(context)
    thing = iterator.eval(context)
    if thing.ruby_value == "<object>"
      thing.runtime_class.runtime_methods.keys.each do |m|
        context.locals[value] = thing.call(m, [])
        context.locals[key] = Constants["String"].new_with_value(m)
        body.eval(context)
      end
      Constants["nil"]
    else
      thing.ruby_value.each do |e|
        context.locals[key] = e
        body.eval(context)
      end
      Constants["nil"]
    end
  end
end

class UnlessNode
  def eval(context)
    if !condition.eval(context).ruby_value
      body.eval(context)
    else # If no body is evaluated, we return nil.
      Constants["nil"]
    end
  end
end
class WhileNode
  def eval(context)
    while condition.eval(context).ruby_value
      body.eval(context)
    end
  end
end
