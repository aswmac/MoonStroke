//
//  Iterate_functions.swift
//  MoonStroke
//
//  Created on 7/5/26.
//

/** call a monotonic function repeatedly doing a binary search for the inverse */
func iterate(function F: (Double) -> Double, for x: Double, start: Double = 0.0) -> Double? {
  let epsilon = 1.0e-15
  var increasing:Bool // flag denoting if the function is increasing or decreasing (looks only at two points to decide...)
  let maxCount = 512 // the most "binary digits" to look for
  let maxMagnitude = 256 // the largest "magnitude mantissa" to look for
  var count = 0
  var magCount = 0
  var domain = Interval(left: start - 100*epsilon, right: start + 100*epsilon)
//  var ll:Double = start - 100*epsilon // left start bound for the search
//  var rr:Double = start + 100*epsilon // right start bound for the search
  var mid:Double // the midpoint
  var Fmid:Double // function of the midpoint
  var Fll = F(domain.left)
  //var Fll = F(ll)
  var Frr = F(domain.right)
  //var Fll = F(rr)
//  print("    ---------------- √¢¢§∞¶¶¶   ------------------------   x = \(x)")
//  print("inverseOf(): left start gives function(\(ll)) = \(Fll)")
//  print("inverseOf(): right start gives function(\(rr)) = \(Frr)")
  while Fll == Frr && count < 300 { // for now use p.d.f. style, it is a step type function so look left/right for 0->1 or 1->0
    Fmid = Frr // store a copy of the single value they both share
    domain.extendRight()
    //rr *= 2.0
    Frr = F(domain.right)
    //Frr = F(rr)
    if Frr != Fmid {
      Fll = Fmid
      break // found some differing values here, so can use them to get a vector to search
    }
    domain.extendLeft()
    //ll *= 2.0
    Fll = F(domain.left)
    //Fll = F(ll)
    count += 1
  }
//  print("inverseOf(): count is \(count)")
//  print("inverseOf(): left epsi-start gives function(\(ll)) = \(Fll)")
//  print("inverseOf(): right epsi-start gives function(\(rr)) = \(Frr)")
//  print("inverseOf(): difference of \(Frr - Fll)")
  count = 0
  if Frr > Fll { increasing = true }
  else { increasing = false }
  //print("inverseOf(): left guess gives function(\(ll)) = \(Fll)")
  if Fll.isNaN { print("Fll was nan!")}
  //print("inverseOf(): right guess gives function(\(rr)) = \(Frr)")
  if increasing { // an increasing function
    while magCount < maxMagnitude && Frr < x { // if the answer is outside the interval to the right, open up the search range to the right
      domain.extendRight(hop: true)
      //(ll, rr) = (rr, 3.0*rr - 2.0*ll) // ll, rr = ll + (rr - ll), ll + 2*(rr - ll), ll + 3*(rr - ll) INSTEAD of //(ll, rr) = (rr, 2.0*rr)
      Fll = Frr // follows the domain hop really, but why eval F again
      Frr = F(domain.right)
      //(Fll, Frr) = (Frr, F(rr))
      magCount += 1
    }
    magCount = 0 // shouldn't be needed, just reiterating that this is the count variable for the while loop here
    while magCount < maxMagnitude && Fll > x { // if the answer is outside the interval to the left, double the size of the interval and shift left
      domain.extendLeft(hop: true)
      //(ll, rr) = (3.0*ll - 2.0*rr, ll) // ll - 3(rr - ll) INSTEAD of //(ll, rr) = (2.0*ll, ll)
      Frr = Fll // follows the domain hop really, but why eval F again
      Fll = F(domain.left)
      //(Fll, Frr) = (F(ll), Fll)
      magCount += 1
    }
    mid = domain.midpoint
    //mid = (ll + rr)/2.0
    Fmid = F(mid)
    while count < maxCount && abs(Fmid - x) > epsilon {
      //print("ll:\(ll) rr:\(rr) Fll:\(Fll) Frr:\(Frr)")
      if Fmid > x {
        domain.trimNew(right: mid)
        //rr = mid // cut off the right side of the interval
        Frr = Fmid
      } else {
        domain.trimNew(left: mid)
        //ll = mid // cut off the left side of the interval
        Fll = Fmid
      }
      mid = domain.midpoint
      //mid = (ll + rr)/2.0
      Fmid = F(mid)
      count += 1
    }
    if abs(Fmid - x) > 1e-5 {
      if start == 0 { // try one more here with a different start variable (example 10+2x-1/x = 0 has V.A. at 0)
        return iterate(function: F, for: x, start: -1.27)
      }
      //print(" Returning nil (FIRST ONE) because of abs(Fmid - x) > 1e-5 ")
      return nil }
    else { return mid }
  } else { // a decreasing function
    while magCount < maxMagnitude && Frr > x { // if the answer is outside the interval to the right, open up the search range to the right
      domain.extendRight(hop: true)
      //(ll, rr) = (rr, 3.0*rr - 2.0*ll) // ll, rr = ll + (rr - ll), ll + 2*(rr - ll), ll + 3*(rr - ll) INSTEAD of //(ll, rr) = (rr, 2.0*rr)
      Fll = Frr
      Frr = F(domain.right)
      //(Fll, Frr) = (Frr, F(rr))
      magCount += 1
    }
    while magCount < maxMagnitude && Fll < x { // if the answer is outside the interval to the left, double the size of the interval and shift left
      //print("  (ll, rr) =  (\(ll), \(rr))       (Fll, Frr) = (\(Fll), \(Frr))")
      domain.extendLeft(hop: true)
      //(ll, rr) = (3.0*ll - 2.0*rr, ll) // ll - 3(rr - ll) INSTEAD of //(ll, rr) = (2.0*ll, ll)
      Frr = Fll
      Fll = F(domain.left)
      //(Fll, Frr) = (F(ll), Fll)
      magCount += 1
    }
    mid = domain.midpoint
    //mid = (ll + rr)/2.0
    Fmid = F(mid)
    while count < maxCount && abs(Fmid - x) > epsilon {
      //print("ll:\(ll) rr:\(rr) Fll:\(Fll) Frr:\(Frr)")
      if Fmid > x {
        domain.trimNew(left: mid)
        //ll = mid // cut off the left side of the interval
        Fll = Fmid
      } else { // cut off the right side of the interval
        domain.trimNew(right: mid)
        //rr = mid
        Frr = Fmid
      }
      mid = domain.midpoint
      //mid = (ll + rr)/2.0
      Fmid = F(mid)
      count += 1
    }
    if abs(Fmid - x) > 1e-5 {
      if start == 0 { // try one more here with a different start variable (example 10+2x-1/x = 0 has V.A. at 0)
        return iterate(function: F, for: x, start: 1.27)
      }
      //print(" Returning nil (SECOND ONE) because of abs(Fmid - x) > 1e-5 ")
      return nil }
    else { return mid }
  }
}
