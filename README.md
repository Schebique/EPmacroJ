# EPJ Macro (Endoost Periost ImageJ Macro)
Repository with ImageJ macro for bone moments measurements based on Jenis Hopkins original MomentMacroJ_v1.4B macro. This macro use selections instead of thresholding for measuremenst. Moreover, there is more ways how to select endoost and periost selections used to moments computation.

# Installation
1) download EPJ_YYMMDD.ijm and install it via "Plugins>Macros>Install..." menu in FIJI or ImageJ.
2) use "Plugins>Macros>Install new version" for instant installation.

# Brief Description
This macro is applicable in the software environment of FIJI and is used for the
calculation of section properties such as areas, second moments of area, and section moduli
(see summary in Ruff 2008, Skedros 2011) using transversal cross-section taken by
CT/micro-CT/MRI/LSCM techniques. The EPJ Macro can help to find the most accurate and
also time-effective way of getting the section properties out of the transversal cross-sections.
This macro allowed creating multiple selections of outer (periost) and inner (endoost)
cortical bone cross-sectional contour, choose a pair of selections (one for periost, one for
endoost), and subsequently calculate the section properties. The periost/endoost selections can
be made either “manually” (selecting the boundary by FIJI Polygon Tool), automatically
(using FIJI algorithm based on ImageJ Auto Threshold) or semi-automatically (by
combination of 4 user-defined points and algorithm-based Spline/Ellipse fitting).

Literature cited:

Ruff CB. 2008. Biomechanical analysis of archaeological human skeletons. In: Katzenberg MA, and Saunders
SR, editors. Biological anthropology of the human skeleton. 2nd ed. New York: Wiley-Liss, Inc. p 183-
206.

Skedros J. 2011. Interpreting load history in limb-bone diaphyses: important considerations and their
biomechanical foundations. In: Crowder CM, and Stout SD, editors. Bone Histology: an Anthropological
Perspective. New York: CRC Press. p 153-220.
