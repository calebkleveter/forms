import XCTest
import VaporForms
import Vapor

/**
 Layout of the vapor-forms library
 - Value: it's a Node for easy Vapor interoperability
 - Validator: a thing which operates on a Type (String, Int, etc) and checks a Value against its own validation rules.
   It returns FieldValidationResult .success or .failure(FieldErrorCollection).
 - Field: a thing which accepts a certain type of Value and holds a number of Validators. It checks a Value against
   its Validators and returns FieldValidationResult .success or .failure(FieldErrorCollection)
 - Fieldset: a collection of Fields which can take an input ValueSet and validate the whole lot against its Fields.
   It returns .success(ValueSet) or .failure(FieldErrorCollection, ValueSet)
 - Form: a protocol for a struct to make a reusable form out of Fieldsets. Can throw because the init needs to
   be implemented by the client (mapping fields to struct properties).

 Errors:
 - FieldError: is an enum of possible error types.
 - FieldErrorCollection: is a specialised collection mapping FieldErrorCollection to field names as String.

 Result sets:
 - FieldValidationResult is either empty .success or .failure(FieldErrorCollection)
 - FieldsetValidationResult is either .success([String: Value]) or .failure(FieldErrorCollection, [String: Value])


 TDD: things a form should do
 ✅ it should be agnostic as to form-encoded, GET, JSON, etc
 ✅ have fields with field types and validation, special case for optionals
 ✅ validate data when inited with request data
 ✅ throw useful validation errors
 - provide useful information on each field to help generate HTML forms but not actually generate them
*/

class VaporFormsTests: XCTestCase {
  static var allTests : [(String, (VaporFormsTests) -> () throws -> Void)] {
    return [
      // ValidationErrors struct
      ("testValidationErrorsDictionaryLiteral", testValidationErrorsDictionaryLiteral),
      ("testValidationErrorsCreateByAppending", testValidationErrorsCreateByAppending),
      // Field validation
      ("testFieldStringValidation", testFieldStringValidation),
      ("testFieldEmailValidation", testFieldEmailValidation),
      ("testFieldIntegerValidation", testFieldIntegerValidation),
      ("testFieldUnsignedIntegerValidation", testFieldUnsignedIntegerValidation),
      ("testFieldDoubleValidation", testFieldDoubleValidation),
      ("testFieldBoolValidation", testFieldBoolValidation),
      // Fieldset
      ("testSimpleFieldset", testSimpleFieldset),
      ("testSimpleFieldsetGetInvalidData", testSimpleFieldsetGetInvalidData),
      // Form
      ("testSimpleForm", testSimpleForm),
      ("testFormValidation", testFormValidation),
      // Binding
      ("testValidateFromContentObject", testValidateFromContentObject),
      ("testValidateFormFromContentObject", testValidateFormFromContentObject),
      // Whole thing use case
      ("testWholeFieldsetUsage", testWholeFieldsetUsage),
    ]
  }

  func expectMatch(_ test: FieldValidationResult, _ match: Node, fail: () -> Void) {
    switch test {
    case .success(let value) where value == match:
      break
    default:
      fail()
    }
  }
  func expectSuccess(_ test: FieldValidationResult, fail: () -> Void) {
    switch test {
    case .success: break
    case .failure: fail()
    }
  }
  func expectFailure(_ test: FieldValidationResult, fail: () -> Void) {
    switch test {
    case .success: fail()
    case .failure: break
    }
  }

  func expectSuccess(_ test: FieldsetValidationResult, fail: () -> Void) {
    switch test {
    case .success: break
    case .failure: fail()
    }
  }
  func expectFailure(_ test: FieldsetValidationResult, fail: () -> Void) {
    switch test {
    case .success: fail()
    case .failure: break
    }
  }

  // MARK: ValidationErrors struct

  func testValidationErrorsDictionaryLiteral() {
    // Must be able to be instantiated by dictionary literal
    let error1 = FieldError.requiredMissing
    let error2 = FieldError.requiredMissing
    let errors: FieldErrorCollection = ["key": [error1, error2]]
    XCTAssertEqual(errors["key"].count, 2)
    // Another way of instantiating
    let errors2: FieldErrorCollection = [
      "key": [error1],
      "key": [error2],
    ]
    XCTAssertEqual(errors2["key"].count, 2)
  }

  func testValidationErrorsCreateByAppending() {
    // Must be able to be instantiated mutably
    let error1 = FieldError.requiredMissing
    let error2 = FieldError.requiredMissing
    var errors: FieldErrorCollection = [:]
    XCTAssertEqual(errors["key"].count, 0)
    errors["key"].append(error1)
    XCTAssertEqual(errors["key"].count, 1)
    errors["key"].append(error2)
    XCTAssertEqual(errors["key"].count, 2)
  }

  // MARK: Field validation

  func testFieldStringValidation() {
    // Correct value should succeed
    expectMatch(StringField().validate("string"), Node("string")) { XCTFail() }
    // Incorrect value type should fail
    expectFailure(StringField().validate(nil)) { XCTFail() }
    // Value too short should fail
    expectFailure(StringField(String.MinimumLengthValidator(characters: 12)).validate("string")) { XCTFail() }
    // Value too long should fail
    expectFailure(StringField(String.MaximumLengthValidator(characters: 6)).validate("maxi string")) { XCTFail() }
    // Value not exact size should fail
    expectFailure(StringField(String.ExactLengthValidator(characters: 6)).validate("wrong size")) { XCTFail() }
  }

  func testFieldEmailValidation() {
    // Correct value should succeed
    expectMatch(StringField(String.EmailValidator()).validate("email@email.com"), "email@email.com") { XCTFail() }
    // Incorrect value type should fail
    expectFailure(StringField(String.EmailValidator()).validate(nil)) { XCTFail() }
    // Value too long should fail
    expectFailure(StringField(String.EmailValidator(), String.MaximumLengthValidator(characters: 6)).validate("email@email.com")) { XCTFail() }
    // Value not of email type should fail
    expectFailure(StringField(String.EmailValidator()).validate("not an email")) { XCTFail() }
  }

  func testFieldIntegerValidation() {
    // Correct value should succeed
    expectMatch(IntegerField().validate(42), Node(42)) { XCTFail() }
    expectMatch(IntegerField().validate("42"), Node(42)) { XCTFail() }
    expectMatch(IntegerField().validate(-42), Node(-42)) { XCTFail() }
    expectMatch(IntegerField().validate("-42"), Node(-42)) { XCTFail() }
    // Incorrect value type should fail
    expectFailure(IntegerField().validate(nil)) { XCTFail() }
    expectFailure(IntegerField().validate("I'm a string")) { XCTFail() }
    // Non-integer number should fail
    expectFailure(IntegerField().validate(3.4)) { XCTFail() }
    expectFailure(IntegerField().validate("3.4")) { XCTFail() }
    // Value too low should fail
    expectFailure(IntegerField(Int.MinimumValidator(42)).validate(4)) { XCTFail() }
    // Value too high should fail
    expectFailure(IntegerField(Int.MaximumValidator(42)).validate(420)) { XCTFail() }
    // Value not exact should fail
    expectFailure(IntegerField(Int.ExactValidator(42)).validate(420)) { XCTFail() }
  }

  func testFieldUnsignedIntegerValidation() {
    // Correct value should succeed
    expectMatch(UnsignedIntegerField().validate(42), Node(42)) { XCTFail() }
    expectMatch(UnsignedIntegerField().validate("42"), Node(42)) { XCTFail() }
    // Incorrect value type should fail
    expectFailure(UnsignedIntegerField().validate(nil)) { XCTFail() }
    expectFailure(UnsignedIntegerField().validate("I'm a string")) { XCTFail() }
    // Non-integer number should fail
    expectFailure(UnsignedIntegerField().validate(3.4)) { XCTFail() }
    expectFailure(UnsignedIntegerField().validate("3.4")) { XCTFail() }
    // Negative integer number should fail
    expectFailure(UnsignedIntegerField().validate(-42)) { XCTFail() }
    expectFailure(UnsignedIntegerField().validate("-42")) { XCTFail() }
    // Value too low should fail
    expectFailure(UnsignedIntegerField(UInt.MinimumValidator(42)).validate(4)) { XCTFail() }
    expectSuccess(UnsignedIntegerField(UInt.MinimumValidator(42)).validate(44)) { XCTFail() }
    // Value too high should fail
    expectFailure(UnsignedIntegerField(UInt.MaximumValidator(42)).validate(420)) { XCTFail() }
    // Value not exact should fail
    expectFailure(UnsignedIntegerField(UInt.ExactValidator(42)).validate(420)) { XCTFail() }
  }

  func testFieldDoubleValidation() {
    // Correct value should succeed
    expectMatch(DoubleField().validate(42.42), Node(42.42)) { XCTFail() }
    expectMatch(DoubleField().validate("42.42"), Node(42.42)) { XCTFail() }
    expectMatch(DoubleField().validate(-42.42), Node(-42.42)) { XCTFail() }
    expectMatch(DoubleField().validate("-42.42"), Node(-42.42)) { XCTFail() }
    // OK to enter an int here too
    expectMatch(DoubleField().validate(42), Node(42)) { XCTFail() }
    expectMatch(DoubleField().validate("42"), Node(42)) { XCTFail() }
    // Incorrect value type should fail
    expectFailure(DoubleField().validate(nil)) { XCTFail() }
    expectFailure(DoubleField().validate("I'm a string")) { XCTFail() }
    // Value too low should fail
    expectFailure(DoubleField(Double.MinimumValidator(4.2)).validate(4.0)) { XCTFail() }
    // Value too high should fail
    expectFailure(DoubleField(Double.MaximumValidator(4.2)).validate(5.6)) { XCTFail() }
    // Value not exact should fail
    expectFailure(DoubleField(Double.ExactValidator(4.2)).validate(42)) { XCTFail() }
    // Precision
    expectFailure(DoubleField(Double.MinimumValidator(4.0000002)).validate(4.0000001)) { XCTFail() }
  }

  func testFieldBoolValidation() {
    // Correct value should succeed
    expectMatch(BoolField().validate(true), Node(true)) { XCTFail() }
    expectMatch(BoolField().validate(false), Node(false)) { XCTFail() }
    // True-ish values should succeed
    expectMatch(BoolField().validate("true"), Node(true)) { XCTFail() }
    expectMatch(BoolField().validate("t"), Node(true)) { XCTFail() }
    expectMatch(BoolField().validate(1), Node(true)) { XCTFail() }
    // False-ish values should succeed
    expectMatch(BoolField().validate("false"), Node(false)) { XCTFail() }
    expectMatch(BoolField().validate("f"), Node(false)) { XCTFail() }
    expectMatch(BoolField().validate(0), Node(false)) { XCTFail() }
  }

  // MARK: Fieldset

  func testSimpleFieldset() {
    // It should be possible to create and validate a Fieldset on the fly.
    var fieldset = Fieldset([
      "string": StringField(),
      "integer": IntegerField(),
      "double": DoubleField()
    ])
    expectSuccess(fieldset.validate([:])) { XCTFail() }
  }

  func testSimpleFieldsetGetInvalidData() {
    // A fieldset passed invalid data should still hold a reference to that data
    var fieldset = Fieldset([
      "string": StringField(),
      "integer": IntegerField(),
      "double": DoubleField()
    ], requiring: ["string", "integer", "double"])
    // Pass some invalid data
    do {
      let result = fieldset.validate([
        "string": "MyString",
        "integer": 42,
      ])
      guard case .failure = result else {
        XCTFail()
        return
      }
      // For next rendering, I should be able to see that data which was passed
      XCTAssertEqual(fieldset.values["string"]?.string, "MyString")
      XCTAssertEqual(fieldset.values["integer"]?.int, 42)
      XCTAssertNil(fieldset.values["gobbledegook"]?.string)
    }
    // Try again with some really invalid data
    // Discussion: should the returned data be identical to what was sent, or should it be
    // "the data we tried to validate against"? For instance, our String validators check that
    // the Node value is actually a String, while Node.string is happy to convert e.g. an Int.
    do {
      let result = fieldset.validate([
        "string": 42,
        "double": "walrus",
        "montypython": 7.7,
      ])
      guard case .failure = result else {
        XCTFail()
        return
      }
//      XCTAssertNil(fieldset.values["string"]?.string) // see discussion above
      XCTAssertNil(fieldset.values["integer"]?.int)
      XCTAssertNil(fieldset.values["double"]?.double)
    }
  }

  // MARK: Form

  func testSimpleForm() {
    // It should be possible to create a type-safe struct around a Fieldset.
    struct SimpleForm: Form {
      let string: String
      let integer: Int
      let double: Double

      static let fieldset = Fieldset([
        "string": StringField(),
        "integer": IntegerField(),
        "double": DoubleField()
      ])

      internal init(validated: [String: Node]) throws {
        string = validated["string"]!.string!
        integer = validated["integer"]!.int!
        double = validated["double"]!.double!
      }
    }
    do {
      let _ = try SimpleForm.validating([
        "string": "String",
        "integer": 1,
        "double": 2,
      ])
    } catch { XCTFail(String(describing: error)) }
  }

  func testFormValidation() {
    struct SimpleForm: Form {
      let string: String
      let integer: Int
      let double: Double?

      static let fieldset = Fieldset([
        "string": StringField(),
        "integer": IntegerField(),
        "double": DoubleField()
      ], requiring: ["string", "integer"])

      internal init(validated: [String: Node]) throws {
        string = validated["string"]!.string!
        integer = validated["integer"]!.int!
        double = validated["double"]?.double
      }
    }
    // Good validation should succeed
    do {
      let _ = try SimpleForm.validating([
        "string": "String",
        "integer": 1,
        "double": 2,
      ])
    } catch { XCTFail(String(describing: error)) }
    // One invalid value should fail
    do {
      let _ = try SimpleForm.validating([
        "string": "String",
        "integer": "INVALID",
        "double": 2,
      ])
    } catch is FieldErrorCollection {
    } catch { XCTFail(String(describing: error)) }
    // Missing optional value should succeed
    do {
      let _ = try SimpleForm.validating([
        "string": "String",
        "integer": 1,
      ])
    } catch { XCTFail(String(describing: error)) }
    // Missing required value should fail
    do {
      let _ = try SimpleForm.validating([
        "string": "String",
      ])
    } catch is FieldErrorCollection {
    } catch { XCTFail(String(describing: error)) }
  }

  // MARK: Binding

  func testValidateFromContentObject() {
    // I want to simulate receiving a Request in POST and binding to it.
    var fieldset = Fieldset([
      "firstName": StringField(),
      "lastName": StringField(),
      "email": StringField(String.EmailValidator()),
      "age": IntegerField(),
    ])
    // request.data is a Content object. I need to create a Content object.
    let content = Content()
    content.append(Node([
      "firstName": "Peter",
      "lastName": "Pan",
      "age": 13,
    ]))
    XCTAssertEqual(content["firstName"]?.string, "Peter")
    // Now validate
    expectSuccess(fieldset.validate(content)) { XCTFail() }
  }

  func testValidateFormFromContentObject() {
    // I want to simulate receiving a Request in POST and binding to it.
    struct SimpleForm: Form {
      let firstName: String?
      let lastName: String?
      let email: String?
      let age: Int?

      static let fieldset = Fieldset([
        "firstName": StringField(),
        "lastName": StringField(),
        "email": StringField(String.EmailValidator()),
        "age": IntegerField(),
      ])

      internal init(validated: [String: Node]) throws {
        firstName = validated["firstName"]?.string
        lastName = validated["lastName"]?.string
        email = validated["email"]?.string
        age = validated["age"]?.int
      }
    }
    // request.data is a Content object. I need to create a Content object.
    let content = Content()
    content.append(Node([
      "firstName": "Peter",
      "lastName": "Pan",
      "age": 13,
    ]))
    XCTAssertEqual(content["firstName"]?.string, "Peter")
    // Now validate
    do {
      let _ = try SimpleForm.validating(content)
    } catch { XCTFail(String(describing: error)) }
  }
  
  // MARK: Whole thing
  
  func testWholeFieldsetUsage() {
    // Test the usability of the whole thing.
    // I want to define a fieldset which can be used to render a view.
    // For that, the fields will need string labels.
    var fieldset = Fieldset([
      "name": StringField(label: "Your name",
        String.MaximumLengthValidator(characters: 255)
      ),
      "age": UnsignedIntegerField(label: "Your age",
        UInt.MinimumValidator(18, message: "You must be 18+.")
      ),
      "email": StringField(label: "Email address",
        String.EmailValidator(),
        String.MaximumLengthValidator(characters: 255)
      ),
    ])
    // Now, I want to be able to render this fieldset in a view.
    // That means I need to be able to convert it to a Node.
    // The node should be able to tell me the `label` for each field.
    do {
      let fieldsetNode = try! fieldset.makeNode()
      XCTAssertEqual(fieldsetNode["name"]?["label"]?.string, "Your name")
      XCTAssertEqual(fieldsetNode["age"]?["label"]?.string, "Your age")
      XCTAssertEqual(fieldsetNode["email"]?["label"]?.string, "Email address")
      // .. Nice to have: other things for the field, such as 'type', 'maxlength'.
      // .. For now, that's up to the view implementer to take care of.
    }
    // I've received data from my rendered view. Validate it.
    do {
      let validationResult = fieldset.validate([
        "name": "Peter Pan",
        "age": 11,
        "email": "peter@neverland.net",
      ])
      // This should have failed
      expectFailure(validationResult) { XCTFail() }
      // Now I should be able to render the fieldset into a view
      // with the passed-in data and also any errors.
      let fieldsetNode = try! fieldset.makeNode()
      XCTAssertEqual(fieldsetNode["name"]?["label"]?.string, "Your name")
      XCTAssertEqual(fieldsetNode["name"]?["value"]?.string, "Peter Pan")
      XCTAssertNil(fieldsetNode["name"]?["errors"])
      XCTAssertEqual(fieldsetNode["age"]?["errors"]?[0]?.string, "You must be 18+.")
    }
    // Let's try and validate it correctly.
    do {
      let validationResult = fieldset.validate([
        "name": "Peter Pan",
        "age": 33,
        "email": "peter@neverland.net",
      ])
      guard case .success(let validatedData) = validationResult else {
        XCTFail()
        return
      }
      XCTAssertEqual(validatedData["name"]!.string!, "Peter Pan")
      XCTAssertEqual(validatedData["age"]!.int!, 33)
      XCTAssertEqual(validatedData["email"]!.string!, "peter@neverland.net")
      // I would now do something useful with this validated data.
    }
  }

}
